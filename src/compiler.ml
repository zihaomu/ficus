(*
    This file is a part of ficus language project.
    See ficus/LICENSE for the licensing terms
*)

(*
    The top-level "driver" module that
    performs all the compilation steps
    in the certain order:

    lexical + syntactic analysis (parsing) =>
    type checking =>
    k-normalization =>
    iterative k-form optimization =>
    final k-form preparation (lambda lifting, name mangling ...) =>
    C code generation =>
    [optional C compiler invocation to process the produced C code]
*)

open Lexing
open Options
open Ast
open K_form
open Utils

exception CumulativeParseError

let make_lexer fname =
    let _ = Lexer.fname := fname in
    let bare_name = Utils.remove_extension (Filename.basename fname) in
    let prev_lnum = ref 0 in
    (* the standard preamble *)
    let tokenbuf = (if bare_name = "Builtins" then ref [] else
        ref [Parser.FROM; Parser.B_IDENT "Builtins"; Parser.IMPORT; Parser.STAR; Parser.SEMICOLON]) in
    let print_token lexbuf t =
      (let s = Lexer.token2str t in
       let pos_lnum = lexbuf.lex_curr_p.pos_lnum in
       if pos_lnum > !prev_lnum then
          ((printf "\n%s (%d): %s" fname pos_lnum s);
          prev_lnum := pos_lnum)
       else print_string (" " ^ s);
       match t with
       Parser.EOF -> print_string "\n"
       | _ -> ()) in
    (fun lexbuf -> let t = match !tokenbuf with
        | t::rest -> tokenbuf := rest; t
        | _ -> (match Lexer.tokens lexbuf with
                | t::rest -> tokenbuf := rest; t
                | _ -> failwith "unexpected end of stream")
        in (if options.print_tokens then print_token lexbuf t else ()); t)

let parse_file fname inc_dirs =
    let fname_id = get_id fname in
    let lexer = make_lexer fname in
    let use_stdin = fname = "stdin" in
    let inchan = if use_stdin then stdin else open_in fname in
    let l = Lexing.from_channel inchan in
    let _ = (parser_ctx_file := fname_id) in
    let _ = (parser_ctx_deps := []) in
    let _ = (parser_ctx_inc_dirs := inc_dirs) in
    try
        let ast = Parser.ficus_module lexer l in
        (if use_stdin then () else close_in inchan;
        ast)
    with
    | e -> close_in inchan; raise e

let parse_all _fname0 =
    let cwd = Sys.getcwd() in
    let fname0 = normalize_path cwd _fname0 in
    let dir0 = Filename.dirname fname0 in
    let fname0 = if _fname0 = "stdin" then _fname0 else fname0 in
    let inc_dirs0 = (if dir0 = cwd then [cwd] else [dir0; cwd]) @ options.include_path in
    let inc_dirs0 = List.map (fun d -> normalize_path cwd d) inc_dirs0 in
    (*let _ = print_string ("Module search path:\n\t" ^ (String.concat ",\n\t" inc_dirs0) ^ "\n") in*)
    let name0_id = get_id (Utils.remove_extension (Filename.basename fname0)) in
    let minfo = find_module name0_id fname0 in
    let queue = ref [!minfo.dm_name] in
    let ok = ref true in
    while !queue != [] do
        let mname = List.hd (!queue) in
        let _ = queue := List.tl (!queue) in
        let minfo = get_module mname in
        let mfname = !minfo.dm_filename in
        if !minfo.dm_parsed then ()
        else
        (try
            let dir1 = Filename.dirname mfname in
            let inc_dirs = (if dir1 = dir0 then [] else [dir1]) @ inc_dirs0 in
            let defs = parse_file mfname inc_dirs in
            let deps = !parser_ctx_deps in
            let _ = (!minfo.dm_defs <- defs) in
            let _ = (!minfo.dm_parsed <- true) in
            let _ = (!minfo.dm_deps <- deps) in
            (* locate the deps, update the list of deps using proper ID's of real modules *)
            List.iter (fun dep ->
                let dep_minfo = get_module dep in
                if not !dep_minfo.dm_parsed then
                    queue := !dep_minfo.dm_name :: !queue
                else ()) deps
        with
        | Lexer.LexError(err, (p0, p1)) ->
            printf "%s: %s\n" (Lexer.pos2str p0 true) err; ok := false
        | SyntaxError(err, p0, p1) ->
            printf "%s: %s\n" (Lexer.pos2str p0 true) err; ok := false
        | Failure(msg) -> (printf "%s: %s\n" mfname msg); ok := false
        | e -> (printf "%s: exception %s occured" mfname (Printexc.to_string e)); ok := false)
    done;
    !ok

let init () =
    ignore(init_all_ids ());
    (Hashtbl.reset all_modules)

(*
  Sort the modules topologically using the algorithm from
  https://stackoverflow.com/questions/4653914/topological-sort-in-ocaml
  Big thanks to Victor Nicollet for the code.
*)
let toposort graph =
    let dfs graph visited start_node =
        let rec explore path visited node =
            if List.mem node path then
                let msg = (sprintf "error: cylic module dependency: %s\n" (String.concat " " (List.map pp_id2str path))) in
                failwith msg
            else if List.mem node visited then visited else
                let new_path = node :: path in
                let edges = List.assoc node graph in
                let visited = List.fold_left (explore new_path) visited edges in
                node :: visited
        in explore [] visited start_node in
    List.fold_left (fun visited (node,_) -> dfs graph visited node) [] graph

let typecheck_all modules =
    let _ = (compile_errs := []) in
    let _ = (List.iter Ast_typecheck.check_mod modules) in
    !compile_errs = []

let k_normalize_all modules =
    let _ = (compile_errs := []) in
    let _ = K_form.init_all_idks() in
    let rkcode = List.fold_left (fun rkcode m ->
        let rkcode_i = K_normalize.normalize_mod m in
        rkcode_i @ rkcode) [] modules in
    (List.rev rkcode, !compile_errs = [])

let k_optimize_all code =
    let _ = (compile_errs := []) in
    let niters = 5 in
    let temp_code = ref code in
    for i = 0 to niters-1 do
        temp_code := K_deadcode_elim.elim_unused !temp_code;
        if i <= 1 then
            temp_code := K_simple_ll.lift !temp_code
        else ();
        temp_code := K_tailrec.tailrec2loops !temp_code;
        temp_code := K_flatten.flatten !temp_code;
        temp_code := K_cfold_dealias.cfold_dealias !temp_code
    done;
    temp_code := K_lift.lift_all !temp_code;
    temp_code := K_deadcode_elim.elim_unused !temp_code;
    temp_code := K_mangle.mangle_all !temp_code;
    temp_code := K_deadcode_elim.elim_unused !temp_code;
    temp_code := K_annotate_types.annotate_types !temp_code;
    (!temp_code, !compile_errs = [])

let k2c_all code =
    let _ = (compile_errs := []) in
    let _ = C_form.init_all_idcs() in
    let _ = C_gen_std.init_std_names() in
    let ccode = C_gen_code.gen_ccode code in
    (ccode, !compile_errs = [])

let run_compiler () =
    let opt_level = options.optimize_level in
    let cmd = "cc" in
    let cmd = cmd ^ (sprintf " -O%d%s" opt_level (if opt_level = 0 then " -ggdb" else "")) in
    let cmd = cmd ^ " -o " ^ options.app_filename in
    let cmd = cmd ^ " -I" ^ options.runtime_path in
    let cmd = cmd ^ " " ^ options.c_filename in
    let cmd = cmd ^ " -lm" in
    let ok = (Sys.command cmd) = 0 in
    if not ok || options.write_c then () else Sys.remove options.c_filename;
    ok

let run_app () =
    let cmd = String.concat " " (options.app_filename :: options.app_args) in
    let ok = (Sys.command cmd) = 0 in
    if options.make_app then () else Sys.remove options.app_filename;
    ok

let print_all_compile_errs () =
    let nerrs = List.length !compile_errs in
    if nerrs = 0 then ()
    else
        (List.iter print_compile_err (List.rev !compile_errs);
        printf "\n%d errors occured during type checking.\n" nerrs)

let process_all fname0 =
    init();
    let ok =
    try
        let _ = if (parse_all fname0) then () else raise CumulativeParseError in
        let graph = Hashtbl.fold (fun mfname m gr ->
            let minfo = get_module m in
            (m, !minfo.dm_deps) :: gr) all_modules [] in
        let _ = (sorted_modules := List.rev (toposort graph)) in
        (*let _ = (printf "Sorted modules: %s\n" (String.concat ", " (List.map id2str !sorted_modules))) in*)
        (*let _ = if options.print_ast then
            (List.iter (fun m -> let minfo = get_module m in Ast_pp.pprint_mod !minfo) !sorted_modules) else () in*)
        let ok = typecheck_all !sorted_modules in
        let _ = if ok && options.print_ast then
            (List.iter (fun m -> let minfo = get_module m in Ast_pp.pprint_mod !minfo) !sorted_modules) else () in
        let (code, ok) = if ok then k_normalize_all !sorted_modules else ([], false) in
        let (code, ok) = if ok then k_optimize_all code else ([], false) in
        let _ = if ok && options.print_k then (K_pp.pprint_top code) else () in
        if not options.gen_c then ok else
            let (ccode, ok) = if ok then k2c_all code else ([], false) in
            let ok = if ok then (C_pp.pprint_top_to_file options.c_filename ccode) else ok in
            let ok = if ok && (options.make_app || options.run_app) then run_compiler() else ok in
            let ok = if ok && options.run_app then run_app() else ok in
            ok
    with
    | Failure msg -> print_string msg; false
    | e -> (printf "\n\nException %s occured" (Printexc.to_string e)); false
    in if not ok then
        print_all_compile_errs()
    else (); ok

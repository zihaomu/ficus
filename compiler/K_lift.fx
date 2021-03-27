/*
    This file is a part of ficus language project.
    See ficus/LICENSE for the licensing terms
*/

/*
    Full-scale lambda lifting.
    Unlike k_simple_ll, this algorithm
    moves all the functions to the top level.

    Also, unlike k_simple_ll, this algorithm is executed after all
    other K-form optimizations, including dead code elimination,
    tail-recursive call elimination, inline expansion etc.
    (But dead code elimination runs once again after it to remove
    some of the generated by this step structures and functions that are not used)

    In order to move all the functions to the top level and preserve
    semantics of the original code, we need to transform some nested functions,
    as well as some outer code that uses those functions.

    * We analyze each function and see if the function has 'free variables',
      i.e. variables that are defined outside of this function and yet are non-global.
    a)  If the function has some 'free variables',
        it needs a special satellite structure called 'closure data'
        that incapsulates all the free variables. The function itself
        is transformed, it gets an extra parameter, which is pointer to the
        closure data (this is done at C code generation step actually).
        All the accesses to free variables are replaced
        with the closure data access operations. Then, when the function
        occurs in code (if it does not occur, it's eliminated as dead code),
        a 'closure' is created, which is a pair (function_pointer, (closure_data or 'nil')).
        This pair is used instead of the original function. Here is the example:

        fun foo(n: int) {
            fun bar(m: int) = m * n
            bar
        }

        is replaced with

        fun bar(m: int, c: bar_closure_t) {
            m * c->n
        }
        fun foo(n: int) {
            make_closure(bar, bar_closure_t {n})
        }

    b)  If the function does not have any 'free variables', we may still
        need a closure, i.e. we may need to represent this function as a pair,
        because in general when we pass a function as a parameter to another function
        or store it as a value (essentially, we store a function pointer), the caller
        of that function does not know whether the called function needs free variables or not,
        so we need a consistent representation of functions that are called indirectly.
        But in this case we can have a pair ('some function', nil), i.e. we just use something like
        NULL pointer instead of a pointer to real closure. So, the following code:

        fun foo(n: int) {
            fun bar(m: int) = m*n // uses free variable 'n'
            fun baz(m: int) = m+1 // does not use any free variables
            if generate_random_number() % 2 == 0 {bar} else {baz}
        }
        val transform_f = foo(5)
        for i <- 0:10 {println(transform_f(i))}

        is transformed to:

        fun bar( m: int, c: bar_closure_t* ) = m*c->n
        fun baz( m: int, _: nil_closure_t* ) = m+1

        fun foo(n: int) =
            if generate_random_number() % 2 == 0
                {make_closure(bar, bar_closure_t {n})}
            else
                {make_closure(baz, nil)}

        val (transform_f_ptr, transform_f_cldata) = foo(5)
        for i <- 0:10 {println(transform_f_ptr(i, transform_f_cldata))}

        However, in the case (b) when we call the function directly, e.g.
        we call 'baz' as 'baz' directly, not via 'transform_f' pointer, we can
        avoid the closure creation step and just call it as, e.g., 'baz(real_arg, nil)'.

    From the above description it may seem that the algorithm is very simple,
    but there are some nuances:

    1.  The nested function with free variables may not just read some values
        declared outside, it may modify mutable values, i.e. var's.
        Or, it may read from a 'var', and yet it may call another nested function
        that may access the same 'var' and modify it. We could have stored an address
        of each var in the closure data, but that would be unsafe, because we may
        return the created closure outside of the function
        (which is a typical functional language pattern for generators, see below)
        where 'var' does not exist anymore. The robust solution for this problem is
        to convert each 'var', which is used at least once as a free variable,
        into a reference, which is allocated on heap:

        fun create_incremetor(start: int) {
            var v = start
            fun inc_me() {
                val temp = v; v += 1; temp
            }
            inc_me
        }
        val counter = create_incrementor(5)
        for i<-0:10 {print(f"{counter()} ")} // 5 6 7 8 ...

        this is converted to:

        fun inc_me( c: inc_me_closure_t* ) {
            val temp = *c->v; *c->v += 1; temp
        }
        fun create_incrementor(start: int) {
            val v = ref(start)
            make_closure(inc_me, inc_me_closure_t {v})
        }

    2.  Besides the free variables, the nested function may also call:
        2a. itself. This is a simple case. We just call it and pass the same closure data, e.g.:
          fun bar( n: int, c: bar_closure_t* ) = if n <= 1 {1} else { ... bar(n-1, c) }
        2b. another function that needs some free variables from the outer scope
            fun foo(n: int) {
                fun bar(m: int) = baz(m+1)
                fun baz(m: int) = m*n
                (bar, baz)
            }

            in order to form the closure for 'baz', 'bar' needs to read 'n' value,
            which it does not access directly. That is, the code can be converted to:

            // option 1: dynamically created closure
            fun bar( m: int, c:bar_closure_t* ) {
                val (baz_cl_f, baz_cl_fv) = make_closure(baz, baz_closure_t {c->n})
                baz_cl_f(m+1, baz_cl_fv)
            }
            fun baz( m: int, c:baz_closure_t* ) = m*c->n
            fun foo(n: int) = (make_closure(bar, bar_closure_t {n}),
                               make_closure(baz, baz_closure_t {n})

            or it can be converted to

            // option 2: nested closure
            fun bar( m: int, c:bar_closure_t* ) {
                val (baz_cl_f, baz_cl_fv) = c->baz_cl
                baz_cl_f(m+1, baz_cl_fv)
            }
            fun baz( m: int, c:baz_closure_t* ) = m*c->n
            fun foo(n: int) = {
                val baz_cl = make_closure(baz, baz_closure_t {n})
                val bar_cl = make_closure(bar, {baz_cl})
                (bar_cl, baz_cl)
            }

            or it can be converted to

            // option 3: shared closure
            fun bar( m: int, c:foo_nested_closure_t* ) {
                baz(m+1, c)
            }
            fun baz( m: int, c:foo_nested_closure_t* ) = m*c->n
            fun foo(n: int) = {
                val foo_nested_closure_data = foo_nested_closure_t {n}
                val bar_cl = make_closure(bar, foo_nested_closure_data)
                val baz_cl = make_closure(baz, foo_nested_closure_data)
                (bar_cl, baz_cl)
            }

        The third option in this example is the most efficient. But in general it may
        be not easy to implement, because between bar() and baz() declarations there
        can be some value definitions, i.e. in general baz() may access some values that
        are computed using bar(), and then the properly initialized shared closure may be
        difficult to build.

        The second option is also efficient, because we avoid repetitive call to
        make_closure() inside bar(). However if not only 'bar' calls 'baz',
        but also 'baz' calls 'bar', it means that both closures need to reference each other,
        so we have a reference cycle and this couple of closures
        (or, in general, a cluster of closures) will never be released.

        So, for simplicity, we just implement the first, i.e. the slowest option.
        It's not a big problem though, because:
        * the language makes an active use of dynamic data structures
          (recursive variants, lists, arrays, strings, references ...) anyway,
          and so the memory allocation is used often, but it's tuned to be efficient,
          especially for small memory blocks.
        * when we get to the lambda lifting
          stage, we already have expanded many function calls inline
        * the remaining non-expanded nested functions that do not need
          free variables are called directly without creating a closure
        * when we have some critical hotspots, we can transform the critical functions and
          pass some 'free variables' as parameters in order to eliminate closure creation.
          (normally hotspot functions operate on huge arrays and/or they can be
          transformed into tail-recursive functions, so 'mutually-recursive functions'
          and 'hotspots' are the words that rarely occur in the same sentence).
        [TODO] The options 1, 2 and 3 are not mutually exclusive; for example, we can use
        the most efficient 3rd option in some easy-to-detect partial cases
        (e.g. when the nested functions go sequentially without any non-trivially
        defined values between them) and use the first option everywhere else.

    3.  In order to implement the first option (2.2b.1) above we need to create an
        iterative algorithm to compute the extended sets of free variables for each
        function. First, for each function we find the directly accessed free variables.
        Then we check which functions we call from this function and combine their
        free variables with the directly accessible ones, and add free variables
        from functions they call etc. We continue to do so until all the sets of
        free variables for all the functions are stabilized and do not change
        on the next iteration.
*/

from Ast import *
from K_form import *
import K_lift_simple
import Map, Set

type ll_func_info_t =
{
    ll_fvars: idset_t ref;
    ll_declared_inside: idset_t;
    ll_called_funcs: idset_t
}

type ll_env_t = (id_t, ll_func_info_t) Map.t
type ll_subst_env_t = (id_t, (id_t, id_t, ktyp_t?)) Map.t

fun make_wrappers_for_nothrow(top_code: kcode_t)
{
    fun wrapf_atom(a: atom_t, loc: loc_t, callb: k_callb_t) =
        match a {
        | AtomId(IdName _) => a
        | AtomId n =>
            match kinfo_(n, loc) {
            | KFun (ref {kf_closure={kci_wrap_f}}) =>
                if kci_wrap_f == noid { a } else { AtomId(kci_wrap_f) }
            | _ => a
            }
        | _ => a
        }
    fun wrapf_ktyp_(t: ktyp_t, loc: loc_t, callb: k_callb_t) = t
    fun wrapf_kexp_(e: kexp_t, callb: k_callb_t) =
        match e {
        | KDefFun kf =>
            val {kf_name, kf_args, kf_rt, kf_flags, kf_body, kf_closure, kf_scope, kf_loc} = *kf
            val new_body = wrapf_kexp_(kf_body, callb)
            *kf = kf->{kf_body=new_body}
            if !kf_flags.fun_flag_nothrow || is_constructor(kf_flags) || kf_closure.kci_wrap_f != noid {
                e
            } else {
                val w_name = gen_idk(pp(kf_name) + "_w")
                *kf = kf->{kf_closure=kf_closure.{kci_wrap_f=w_name}}
                val w_flags = kf_flags.{fun_flag_nothrow=false}
                val w_args =
                [: for (a, t) <- kf_args {
                    val w_a = dup_idk(a)
                    val _ = create_kdefval(w_a, t, default_arg_flags(), None, [], kf_loc)
                    (w_a, t)
                } :]
                val w_body = KExpCall(kf_name, [: for (i, _) <- w_args { AtomId(i) } :], (kf_rt, kf_loc))
                val code = create_kdeffun(w_name, w_args, kf_rt, w_flags, Some(w_body), e :: [], kf_scope, kf_loc)
                rcode2kexp(code, kf_loc)
            }
        | KExpCall(f, args, (t, loc)) =>
            val args = [: for a <- args { wrapf_atom(a, loc, callb) } :]
            KExpCall(f, args, (t, loc))
        | _ => walk_kexp(e, callb)
        }

    val callb = k_callb_t {kcb_ktyp=Some(wrapf_ktyp_), kcb_kexp=Some(wrapf_kexp_), kcb_atom=Some(wrapf_atom)}
    val top_kexp = code2kexp(top_code, noloc)
    // do 2 passes to cover both forward and backward references
    val top_kexp = wrapf_kexp_(top_kexp, callb)
    val top_kexp = wrapf_kexp_(top_kexp, callb)
    kexp2code(top_kexp)
}

fun lift_all(kmods: kmodule_t list)
{
    var fold globals = empty_idset for {km_top} <- kmods {
            K_lift_simple.find_globals(km_top, globals)
        }

    var ll_env : ll_env_t = Map.empty(cmp_id)
    var orig_subst_env : ll_subst_env_t = Map.empty(cmp_id)

    fun fold_fv0_ktyp_(t: ktyp_t, loc: loc_t, callb: k_fold_callb_t) {}
    fun fold_fv0_kexp_(e: kexp_t, callb: k_fold_callb_t) {
        fold_kexp(e, callb)
        match e {
        | KDefFun (ref {kf_name, kf_loc}) =>
            val (uv, dv) = used_decl_by_kexp(e)
            // from the set of free variables we exclude global functions, values and types
            // because they do not have to be put into a closure anyway
            val fv0 = uv.diff(dv).diff(globals)
            val called_funcs =
                uv.foldl(
                    fun (n, called_funcs) {
                        match kinfo_(n, kf_loc) {
                        | KFun _ =>
                            if globals.mem(n) { called_funcs }
                            else { called_funcs.add(n) }
                        | _ => called_funcs
                        }
                    }, empty_idset)
            val fv0 = fv0.filter(fun (fv) {
                match kinfo_(fv, kf_loc) {
                | KVal _ => true
                | _ => false
                }})
            ll_env = ll_env.add(kf_name,
                ll_func_info_t {
                    ll_fvars=ref fv0, ll_declared_inside=dv,
                    ll_called_funcs=called_funcs
                })
        | _ => {}
        }
    }

    val fv0_callb = k_fold_callb_t
    {
        kcb_fold_atom=None,
        kcb_fold_ktyp=Some(fold_fv0_ktyp_),
        kcb_fold_kexp=Some(fold_fv0_kexp_)
    }
    /* for each function, top-level or not, find the initial set of free variables,
       as well as the set of called functions */
    for {km_top} <- kmods {
        for e <- km_top { fold_fv0_kexp_(e, fv0_callb) }
    }
    fun finalize_sets(iters: int, ll_all: id_t list)
    {
        var visited_funcs = empty_idset
        var changed = false
        if iters <= 0 {
            throw compile_err(noloc, "finalization of the free var sets takes too much iterations")
        }
        fun update_fvars(f: id_t): idset_t =
            match ll_env.find_opt(f) {
            | Some ll_info =>
                val {ll_fvars, ll_declared_inside, ll_called_funcs} = ll_info
                if visited_funcs.mem(f) {
                    *ll_fvars
                } else {
                    visited_funcs = visited_funcs.add(f)
                    val size0 = ll_fvars->size
                    val fvars =
                        ll_called_funcs.foldl(
                            fun (called_f: id_t, fvars: idset_t) {
                                val called_fvars = update_fvars(called_f)
                                fvars.union(called_fvars)
                            },
                            *ll_fvars)
                    val fvars = fvars.diff(ll_declared_inside)
                    val size1 = fvars.size
                    if size1 != size0 {
                        *ll_info.ll_fvars = fvars
                        changed = true
                    }
                    fvars
                }
            | _ => empty_idset
            }

        for f <- ll_all { ignore(update_fvars(f)) }
        if !changed { iters - 1 }
        else { finalize_sets(iters - 1, ll_all.rev()) }
    }

    // now compute the closure of the free var sets,
    // i.e. all the free variables of each function,
    // directly accessed or via other functions that the function calls.
    // The term 'closure' is used here with a different meaning,
    // it's not a function closure but rather a transitive closure of the set.
    val iters0 = 10
    val ll_all = ll_env.foldl(fun (f, _, ll_all) { f :: ll_all }, []).rev()
    val _ = finalize_sets(iters0, ll_all)
    val all_fvars = ll_env.foldl(
            fun (_, ll_info, all_fvars) {
                all_fvars.union(*ll_info.ll_fvars)
            }, empty_idset)
    // find which of the free variables are mutable
    val all_mut_fvars = all_fvars.filter(
        fun (i) {is_mutable(i, get_idk_loc(i, noloc)) })
    // each mutable variable, which is a free variable of at least one function
    // needs to be converted into a reference. The reference (as a reference)
    // should be stored in the corresponding function closure,
    // but all other accesses to this variable will be done
    // via dereferencing operator, unary '*'.
    all_mut_fvars.app(
        fun (mut_fv) {
            val kv = get_kval(mut_fv, noloc)
            val {kv_name, kv_typ, kv_flags, kv_loc} = kv
            val new_kv_name = gen_temp_idk(pp(kv_name) + "_ref")
            val new_kv_typ = KTypRef(kv_typ)
            val new_kv_flags = kv_flags.{val_flag_mutable=false}
            val new_kv = kdefval_t { kv_name=new_kv_name,
                kv_cname="", kv_typ=new_kv_typ,
                kv_flags=new_kv_flags, kv_loc=kv_loc }
            val new_old_kv = kv.{kv_flags=kv_flags.{val_flag_tempref=true}}
            set_idk_entry(new_kv_name, KVal(new_kv))
            set_idk_entry(kv_name, KVal(new_old_kv))
            orig_subst_env = orig_subst_env.add(kv_name, (kv_name, new_kv_name, None))
        })

    fun fold_defcl_ktyp_(t: ktyp_t, loc: loc_t, callb: k_fold_callb_t) {}

    // form a closure for each function that has free variables (mutable or not)
    fun fold_defcl_kexp_(e: kexp_t, callb: k_fold_callb_t)
    {
        fold_kexp(e, callb)
        match e {
        | KDefFun kf =>
            val {kf_name, kf_args, kf_rt, kf_closure, kf_flags, kf_scope, kf_loc} = *kf
            match ll_env.find_opt(kf_name) {
            | Some ll_info =>
                val fvars = ll_info.ll_fvars
                if !fvars->empty() {
                    val fvar_pairs_to_sort = fvars->foldl(
                        fun (fv, fvars_to_sort) {
                            (string(fv), fv) :: fvars_to_sort
                        }, [])
                    // just to make sure that closure stays stable with minor modifications
                    // of the program all the free variables are sorted by name
                    val fvar_pairs_sorted = fvar_pairs_to_sort.sort(fun ((a, _), (b, _)) { a < b })
                    val fvars_final = [: for (_, fv) <- fvar_pairs_sorted {fv} :]
                    val fcv_tn = gen_temp_idk(id2prefix(kf_name) + "_closure")
                    val fold fvars_wt = [] for fv@idx <- fvars_final {
                        val {kv_typ, kv_flags, kv_loc} = get_kval(fv, kf_loc)
                        val kv_typ = if all_mut_fvars.mem(fv) { KTypRef(kv_typ) }
                                     else { kv_typ }
                        val new_fv = dup_idk(fv)
                        val _ = create_kdefval(new_fv, kv_typ, kv_flags, None, [], kv_loc)
                        (new_fv, kv_typ) :: fvars_wt
                    }
                    val fcv_t = ref (kdefclosurevars_t {
                            kcv_name=fcv_tn,
                            kcv_cname="",
                            kcv_freevars=fvars_wt.rev(),
                            kcv_orig_freevars=fvars_final,
                            kcv_scope=kf_scope,
                            kcv_loc=kf_loc
                            })
                    val make_args_ktyps = [: for (_, t) <- fvars_wt {t} :]
                    val kf_typ = get_kf_typ(kf_args, kf_rt)
                    val cl_arg = gen_temp_idk("cv")
                    val make_fp = gen_temp_idk("make_fp")
                    val _ = create_kdefconstr(make_fp, make_args_ktyps.rev(), kf_typ, CtorFP(kf_name), [], kf_scope, kf_loc)
                    val _ = create_kdefval(cl_arg, KTypName(fcv_tn), default_val_flags(), None, [], kf_loc)

                    /*
                        kf_closure.kci_arg is the id of argument that is used
                        to pass closure data to each function.

                        Initially, kci_arg is set to 'noid' for each function.
                        Which means that the function does not use any free variables.
                        It will still have this void* fx_fv parameter, but it will not be used.
                        During this lambda lifting step we find out which functions use free variables,
                        And we give a special name to the corresponding parameter
                        (because we need to extract free variables from the closure in the function prologue).

                        kf_closure.kci_fcv_t is the name of type that represents the function closure data structure
                        (which is dynamically allocated and which stores the reference counter,
                        pointer to the destructor and the free variables themselves).

                        kf_closure.kci_make_fp is the constructor of the closure
                    */
                    val new_kf_closure = kf_closure.{kci_arg=cl_arg, kci_fcv_t=fcv_tn, kci_make_fp=make_fp}
                    set_idk_entry(fcv_tn, KClosureVars(fcv_t))
                    *kf = kf->{kf_closure=new_kf_closure, kf_flags=kf_flags.{fun_flag_uses_fv=true}}
                }
            | _ => {}
            }
        | _ => {}
        }
    }

    val defcl_callb = k_fold_callb_t
    {
        kcb_fold_atom=None,
        kcb_fold_ktyp=Some(fold_defcl_ktyp_),
        kcb_fold_kexp=Some(fold_defcl_kexp_)
    }

    // we keep track of all defined values. It helps us to detect situations
    // when KForm is broken after some optimizations and a value is used
    // before it's declared.
    var defined_so_far = empty_idset
    var curr_clo = (noid, noid, noid)
    var curr_top_code : kcode_t = []
    var curr_subst_env : ll_subst_env_t = Map.empty(cmp_id)
    var curr_lift_extra_decls : kcode_t = []
    fun add_to_defined_so_far(i: id_t) =
        defined_so_far = defined_so_far.add(i)

    // During lambda lifting we we need not only to transform the lifted functions'
    // bodies and function calls expressions, we potentially need to transform various atoms
    // used in expressions, as right-hand-side values in val/var declaration etc.
    fun walk_atom_n_lift_all_adv(a: atom_t, loc: loc_t, get_mkclosure_arg: bool) =
        match a {
        | AtomId(IdName _) => a
        | AtomId n =>
            match curr_subst_env.find_opt(n) {
            | Some((_, _, Some f_typ)) =>
                /*
                    The atom is id, corresponding to a function that does not have/need a closure
                    still, since we are here, it means that the function is not called directly,
                    but is rather used as a value, i.e. it's passed to another function,
                    returned from a function or is stored somewhere.

                    We need to construct a light-weight closure on-fly, which will be a pair
                    (function_pointer, <null pointer to closure data>). It's done with
                    KExpMkClosure with the 'noid' constructor and the empty list of free vars.

                    But here is the trick. walk_atom() hook can only return an atom.
                    Therefore we put the extra closure definition into 'curr_lift_extra_decls',
                    which is then handled in walk_kexp() hook (i.e. walk_kexp_n_lift_all()).
                */
                val temp_cl = dup_idk(n)
                val make_cl = KExpMkClosure(noid, n, [], (f_typ, loc))
                curr_lift_extra_decls = create_kdefval(temp_cl, f_typ, default_val_flags(),
                                                Some(make_cl), curr_lift_extra_decls, loc)
                AtomId(temp_cl)
            | Some((nv, nr, _)) =>
                /*
                    There is already pre-declared closure, we just replace
                    function name with the constructed closure
                */
                if get_mkclosure_arg { AtomId(nr) } else { AtomId(nv) }
            | _ =>
                val a =
                match kinfo_(n, loc) {
                | KFun (ref {kf_flags, kf_args, kf_rt, kf_closure={kci_arg}}) =>
                    /*
                    This case is very similar to the first one above, but in this
                    case the global function (and thus the function that does not use free variables)
                    is accessed as a value before we got to its declaration
                    and put Some((noid, noid, Some(func_type))) to the current substitution environment.
                    No big deal, we can still form the closure with null closure data pointer on-fly
                    */
                    if is_constructor(kf_flags) {
                        a // type constructors are handled separately
                    } else if kci_arg == noid {
                        // double-check that the function does not use free variables.
                        // If it does then in theory we should not get here.
                        val temp_cl = dup_idk(n)
                        val f_typ = get_kf_typ(kf_args, kf_rt)
                        val make_cl = KExpMkClosure(noid, n, [], (f_typ, loc))
                        curr_lift_extra_decls = create_kdefval(temp_cl, f_typ, default_val_flags(),
                                                               Some(make_cl), curr_lift_extra_decls, loc)
                        AtomId(temp_cl)
                    } else {
                        throw compile_err(loc, f"for the function '{idk2str(n, loc)}' there is no corresponding closure")
                    }
                | _ => a
                }

                // If it's a mutable value, the atom is automatically renamed to its deferenced alias.
                // But when we build a new closure and want to put this value there, we need to use
                // the original reference, which we found in orig_subst_env.
                if !get_mkclosure_arg {
                    a
                } else {
                    match orig_subst_env.find_opt(n) {
                    | Some((_, nr, _)) => AtomId(nr)
                    | _ => a
                    }
                }
            }
        | _ => a
        }
    fun walk_atom_n_lift_all(a: atom_t, loc: loc_t, callb: k_callb_t) =
        walk_atom_n_lift_all_adv(a, loc, false)
    // pass-by processing types
    fun walk_ktyp_n_lift_all(t: ktyp_t, loc: loc_t, callb: k_callb_t) = t
    fun walk_kexp_n_lift_all(e: kexp_t, callb: k_callb_t)
    {
        val saved_extra_decls = curr_lift_extra_decls
        curr_lift_extra_decls = []
        val e =
        match e {
        | KDefFun kf =>
            val {kf_name, kf_args, kf_body, kf_closure, kf_loc} = *kf
            val {kci_arg, kci_fcv_t, kci_make_fp, kci_wrap_f} = kf_closure
            fun create_defclosure(kf: kdeffun_t ref, code: kcode_t, loc: loc_t)
            {
                val {kf_name, kf_args, kf_rt, kf_closure={kci_make_fp=make_fp}, kf_flags, kf_loc} = *kf
                val kf_typ = get_kf_typ(kf_args, kf_rt)
                val (_, orig_freevars) = get_closure_freevars(kf_name, kf_loc)
                if orig_freevars == [] {
                    if !is_constructor(kf_flags) {
                        curr_subst_env = curr_subst_env.add(kf_name, (noid, noid, Some(kf_typ)))
                    }
                    KExpNop(loc) :: code
                } else {
                    val cl_name = dup_idk(kf_name)
                    curr_subst_env = curr_subst_env.add(kf_name, (cl_name, cl_name, None))
                    add_to_defined_so_far(cl_name)
                    val cl_args =
                    [: for fv <- orig_freevars {
                        if !defined_so_far.mem(fv) {
                            throw compile_err(kf_loc, f"free variable '{idk2str(fv, kf_loc)}' of '{idk2str(kf_name, kf_loc)}' is not defined yet")
                        }
                        walk_atom_n_lift_all_adv(AtomId(fv), kf_loc, true)
                    } :]
                    val make_cl = KExpMkClosure(make_fp, kf_name, cl_args, (kf_typ, kf_loc))
                    create_kdefval(cl_name, kf_typ, default_val_flags(), Some(make_cl), code, kf_loc)
                }
            }

            val def_fcv_t_n_make =
                if kci_fcv_t == noid {
                    []
                } else {
                    val kcv =
                    match kinfo_(kci_fcv_t, kf_loc) {
                        | KClosureVars kcv => kcv
                        | _ => throw compile_err(kf_loc,
                            f"closure type '{idk2str(kci_fcv_t, kf_loc)}' for '{idk2str(kf_name, kf_loc)}' information is not valid (should be KClosureVars ...)")
                        }
                    val make_kf =
                        match kinfo_(kci_make_fp, kf_loc) {
                        | KFun make_kf => make_kf
                        | _ => throw compile_err(kf_loc,
                            f"make_fp '{idk2str(kci_make_fp, kf_loc)}' for '{idk2str(kf_name, kf_loc)}' information is not valid (should be KClosureVars ...)")
                        }
                    [: KDefFun(make_kf), KDefClosureVars(kcv) :]
                }
            val out_e =
                if kci_wrap_f != noid {
                    KDefFun(kf)
                } else {
                    /*
                        We may produce some extra definitions for each function, such as
                        the closure constructor definition, the closure data type definition etc.
                        those extra definitions will be put into curr_top_code.

                        In this case we put the lifted function and associated definitinos
                        to the 'curr_top_code', whereas the function definition itself in some nested block
                        is replaced with the actual closure creation call, because this is the best place
                        where all the free variables the function accesses should be defined.
                    */
                    val extra_code = create_defclosure(kf, [], kf_loc)
                    curr_top_code = extra_code.tl() + def_fcv_t_n_make + (KDefFun(kf) :: []) + curr_top_code
                    extra_code.hd()
                }
            // form the prologue where we extract all free variables from the closure data
            val saved_dsf = defined_so_far
            val saved_clo = curr_clo
            val saved_subst_env = curr_subst_env
            // we set the current closure to handle recursive functions. If a function
            // (with free variables or not) calls itself recursively, we don't need another closure
            // we just pass the closure data parameter directly to it.
            curr_clo = (kf_name, kci_arg, kci_fcv_t)
            for (arg, _) <- kf_args { add_to_defined_so_far(arg) }
            val prologue =
                if kci_fcv_t == noid {
                    []
                } else {
                    val kcv =
                        match kinfo_(kci_fcv_t, kf_loc) {
                        | KClosureVars kcv => kcv
                        | _ => throw compile_err(kf_loc,
                            f"closure type '{idk2str(kci_fcv_t, kf_loc)}' for '{idk2str(kf_name, kf_loc)}' information is not valid (should be KClosureVars ...)")
                        }
                    val {kcv_freevars, kcv_orig_freevars} = *kcv
                    val fold prologue = [] for (fv, t)@idx <- kcv_freevars, fv_orig <- kcv_orig_freevars {
                        if !defined_so_far.mem(fv_orig) {
                            throw compile_err(kf_loc,
                                f"free variable '{idk2str(fv_orig, kf_loc)}' of function '{idk2str(kf_name, kf_loc)}' is not defined before the function body")
                        }
                        val fv_proxy = dup_idk(fv)
                        add_to_defined_so_far(fv_proxy)
                        val (t, kv_flags) =
                            match kinfo_(fv_orig, kf_loc) {
                            | KVal ({kv_typ, kv_flags}) => (kv_typ, kv_flags)
                            | _ => (t, default_val_flags())
                            }
                        val is_mutable = all_mut_fvars.mem(fv_orig)
                        val kv_flags = kv_flags.{val_flag_tempref=false, val_flag_arg=false, val_flag_global=[]}
                        val (e, prologue, fv_proxy_mkclo_arg) =
                        if !is_mutable {
                            (KExpMem(kci_arg, idx, (t, kf_loc)), prologue, fv_proxy)
                        } else {
                            val ref_typ = KTypRef(t)
                            val fv_ref = gen_idk(pp(fv) + "_ref")
                            val get_fv = KExpMem(kci_arg, idx, (ref_typ, kf_loc))
                            val ref_flags = kv_flags.{val_flag_tempref=true, val_flag_mutable=false, val_flag_global=[]}
                            val prologue = create_kdefval(fv_ref, ref_typ, ref_flags, Some(get_fv), prologue, kf_loc)
                            (KExpUnary(OpDeref, AtomId(fv_ref), (t, kf_loc)), prologue, fv_ref)
                        }
                        curr_subst_env = curr_subst_env.add(fv_orig, (fv_proxy, fv_proxy_mkclo_arg, None))
                        val new_kv_flags = kv_flags.{val_flag_tempref=true}
                        create_kdefval(fv_proxy, t, new_kv_flags, Some(e), prologue, kf_loc)
                    }

                    match ll_env.find_opt(kf_name) {
                    | Some({ll_declared_inside, ll_called_funcs}) =>
                        val called_fs = ll_called_funcs.diff(ll_declared_inside)
                        called_fs.foldl(
                            fun (called_f, prologue) {
                                match kinfo_(called_f, kf_loc) {
                                | KFun called_kf =>
                                    val {kf_closure={kci_fcv_t=called_fcv_t}} = *called_kf
                                    if called_fcv_t == noid {
                                        prologue
                                    } else {
                                        create_defclosure(called_kf, prologue, kf_loc)
                                    }
                                | _ => prologue
                                }
                            }, prologue)
                    | _ => throw compile_err(kf_loc, f"missing 'lambda lifting' information about function '{idk2str(kf_name, kf_loc)}'")
                    }
                }
            // now process the body.
            val body_loc = get_kexp_loc(kf_body)
            val body = code2kexp(prologue.rev() + kexp2code(kf_body), body_loc)
            val body = walk_kexp_n_lift_all(body, callb)
            // restore everything. We don't know anything about locally defined values etc. anymore.
            defined_so_far = saved_dsf
            curr_clo = saved_clo
            curr_subst_env = saved_subst_env
            *kf = kf->{kf_body=body}
            out_e
        | KDefExn (ref {ke_tag}) =>
            add_to_defined_so_far(ke_tag)
            walk_kexp(e, callb)
        | KDefVal(n, rhs, loc) =>
            val rhs = walk_kexp_n_lift_all(rhs, callb)
            val is_mutable_fvar = all_mut_fvars.mem(n)
            add_to_defined_so_far(n)
            if !is_mutable_fvar {
                KDefVal(n, rhs, loc)
            } else {
                val t = get_kexp_typ(rhs)
                val ref_typ = KTypRef(t)
                val nr =
                    match orig_subst_env.find_opt(n) {
                    | Some((_, nr, None )) => nr
                    | _ => throw compile_err(loc, f"k-lift: not found subst info about mutable free var '{idk2str(n, loc)}'")
                    }
                val (a, code) = kexp2atom(pp(n) + "_arg", rhs, false, [])
                val code = KDefVal(nr, KExpUnary(OpMkRef, a, (ref_typ, loc)), loc) :: code
                val code = KDefVal(n, KExpUnary(OpDeref, AtomId(nr), (t, loc)), loc) :: code
                KExpSeq(code.rev(), (KTypVoid, loc))
            }
        | KExpFor(idom_l, at_ids, body, flags, loc) =>
            val idom_l = [: for (i, dom_i) <- idom_l {
                             val dom_i = check_n_walk_dom(dom_i, loc, callb)
                             add_to_defined_so_far(i)
                             (i, dom_i)
                            } :]
            for i <- at_ids { add_to_defined_so_far(i) }
            val body = walk_kexp_n_lift_all(body, callb)
            KExpFor(idom_l, at_ids, body, flags, loc)
        | KExpMap(e_idom_ll, body, flags, (etyp, eloc) as kctx) =>
            val e_idom_ll =
            [: for (e, idom_l, at_ids) <- e_idom_ll {
                val e = walk_kexp_n_lift_all(e, callb)
                val fold idom_l = [] for (i, dom_i) <- idom_l {
                    val dom_i = check_n_walk_dom(dom_i, eloc, callb)
                    add_to_defined_so_far(i)
                    (i, dom_i) :: idom_l
                }
                for i <- at_ids { add_to_defined_so_far(i) }
                (e, idom_l.rev(), at_ids)
            } :]
            val body = walk_kexp_n_lift_all(body, callb)
            KExpMap(e_idom_ll, body, flags, kctx)
        | KExpMkClosure(make_fp, f, args, (typ, loc)) =>
            val args = [: for a <- args { walk_atom_n_lift_all_adv(a, loc, true) } :]
            KExpMkClosure(make_fp, f, args, (typ, loc))
        | KExpCall(f, args, (_, loc) as kctx) =>
            val args = [: for a <- args { walk_atom_n_lift_all(a, loc, callb) } :]
            val (curr_f, _, _) = curr_clo
            if f == curr_f {
                KExpCall(f, args, kctx)
            } else {
                match kinfo_(f, loc) {
                | KFun (ref {kf_closure={kci_fcv_t}}) =>
                    if kci_fcv_t == noid { KExpCall(f, args, kctx) }
                    else { KExpCall(check_n_walk_id(f, loc, callb), args, kctx) }
                | _ => KExpCall(check_n_walk_id(f, loc, callb), args, kctx)
                }
            }
        | _ => walk_kexp(e, callb)
        }
        val e = if curr_lift_extra_decls == [] { e }
                else { rcode2kexp(e :: curr_lift_extra_decls, get_kexp_loc(e)) }
        curr_lift_extra_decls = saved_extra_decls
        e
    }

    val walk_n_lift_all_callb = k_callb_t
    {
        kcb_atom=Some(walk_atom_n_lift_all),
        kcb_ktyp=Some(walk_ktyp_n_lift_all),
        kcb_kexp=Some(walk_kexp_n_lift_all)
    }

    [: for km <- kmods {
        val {km_top} = km
        val new_top = make_wrappers_for_nothrow(km_top)
        curr_top_code = []
        for e <- new_top { fold_defcl_kexp_(e, defcl_callb) }
        for e <- new_top {
            val e = walk_kexp_n_lift_all(e, walk_n_lift_all_callb)
            curr_top_code = e :: curr_top_code
        }
        km.{km_top=curr_top_code.rev()}
    } :]
}

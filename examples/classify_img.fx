import Json, Sys, LexerUtils as Lxu
import OpenCV as cv
//import Image.Decoder
import NN.Ast, NN.Inference, NN.FromOnnx, NN.FuseBasic, NN.BufferAllocator, NN.OpConv

var mname = "", lname = ""
var images: string list = []
var ntasks = 0
var use_f16 = false

fun parse_args(args: string list)
{
    | "-ntasks" :: ntasks_ :: rest =>
        ntasks = ntasks_.to_int_or(0); parse_args(rest)
    | "-f16" :: rest =>
        use_f16 = true; parse_args(rest)
    | "-labels" :: lname_ :: rest =>
        lname = lname_; parse_args(rest)
    | "-model" :: mname_ :: rest =>
        mname = mname_; parse_args(rest)
    | optname :: _ when optname.startswith('-') =>
        println(f"error: unknown option {optname}"); throw Fail("")
    | imgname :: rest =>
        images = imgname :: images; parse_args(rest)
    | _ => {}
}

parse_args(Sys.arguments())
images = images.rev()
//println(f"model='{mname}', lname='{lname}', images={images}")

val labels: string [] =
    if lname == "" {[]}
    else {
        try {
            match Json.parse_file(lname) {
            | Json.Map(entries) =>
                val fold maxk = 0 for (k, v) <- entries {
                    val ik = k.to_int().value_or(-1)
                    assert(ik >= 0)
                    max(maxk, ik)
                }
                val labels_arr = array(maxk + 1, "unknown")
                for (k, v) <- entries {
                    val ik = k.to_int().value_or(-1)
                    val v = match v {
                        | Json.Str(s) => s
                        | _ => println(f"invalid label for {k}"); throw Fail("")
                        }
                    labels_arr[ik] = v
                }
                labels_arr
            | _ => println("invalid labels"); throw Fail("")
            }
        } catch {
        | Lxu.LexerError(lloc, msg) => println(f"{lname}:{lloc.0}: error: {msg}"); throw Fail("")
        }
    }

val net = cv.readNet(mname)
/*val fface = cv.makeFontFace("sans")
val fontSize = 20

for imgname@i <- images {
    val img = cv.imread(imgname)
    val inp = cv.blobFromImage(img, size=(224, 224),
            mean=(104.00698793, 116.66876762, 122.67891434),
            swapRB=false, crop=false)
    val probs = net.forward(inp)
    val (_, _, _, n) = size(probs)
    val tprobs = [for i <- 0:n {(probs[0, 0, 0, i], i)}]
    sort(tprobs, (>))
    for j <- 0:5 {
        val lbl = if labels != [] {labels[tprobs[j].1]} else {f"class_{tprobs[j].1}"}
        val p = tprobs[j].0
        cv.putText(img, f"{lbl}: p={round(p, 3)}",
            (10, 30 + j*(fontSize+5)), cv.RGB(0, 255, 0), weight=400, fontFace=fface, size=fontSize)
    }
    cv.imshow(f"image #{i+1}", img)
}
cv.waitKey()
*/

val model =
    try NN.FromOnnx.read(mname)
    catch {
    | NN.FromOnnx.OnnxConvertError(msg) =>
        println(f"error: {msg}"); throw Fail("")
    | Fail(msg) =>
        println(f"error: {msg}"); throw Fail("")
    }
val model = NN.FuseBasic.fuse_basic(model)
val model = NN.BufferAllocator.assign_buffers(model)
println(model)
val k = 5
val lname = "output"
val ocv_outputs = [lname]
val temp_outputs = [for i <- [lname] {(i, NN.Ast.empty_tensor())}]

type nn_output_t = (string, NN.Ast.nntensor_t)
if ntasks > 0 {
    *model.ntasks = ntasks
}
*model.use_f16 = use_f16

for imgname@i <- images {
    println(f"starting reading model '{mname}'")
    val img = cv.imread(imgname)
    val inp = cv.blobFromImage(img, size=(224, 224),
            scaleFactor=0.017,
            mean=(103., 116., 123.),
            swapRB=false, crop=false)
    println(inp.size())
    val out = net.forward(inp)
    //println(f"out[1]={out[1][:]}")
    //println(f"out[2]={out[2][:]}")
    val probs = out
    val (_, _, _, n) = size(probs)
    val tprobs = [for i <- 0:n {(probs[0, 0, 0, i], i)}]
    sort(tprobs, (>))
    val inp_ = NN.Ast.make_tensor(inp)
    var outputs: nn_output_t [] = []
    NN.OpConv.reset_min_total_time_1x1()
    val niters = 15
    val (gmean, mintime) = Sys.timeit(
        fun () {
            outputs =
            try NN.Inference.run(model, [("", inp_)], outputs=temp_outputs) catch {
            | NN.Ast.NNError msg => println(f"exception NNError('{msg}') occured"); []
            | Fail msg => println(f"failure: '{msg}'"); []
            }
        }, iterations=niters, batch=1)
    val total_time = NN.OpConv.get_total_time_1x1()*1000/Sys.tick_frequency()
    println(f"execution time: gmean={gmean*1000.}, mintime={mintime*1000.}, 1x1 total={total_time} ms")
    /*for t_out@i <- temp_outputs {
        println(f"temp output #{i}: name='{t_out.0}', shape={t_out.1.shape}")
    }
    val temp = float(temp_outputs[1].1)
    val shape = temp_outputs[1].1.shape.shape
    val shape2d = (shape[0]*shape[1]*shape[2], shape[3])
    //val ntemp = temp.size()
    //println(f"||'{lname}_ref' - '{lname}'||/sz = {normL1(out[0][:] - temp)/ntemp}")
    //println(out[0].reshape(shape2d)[:5,:5])
    println(temp.reshape(shape2d)[:5,:5])*/
    //println(out[0][:][:20])
    for out@i <- outputs {
        println(f"output #{i}: name='{out.0}', shape={out.1.shape}: top-{k}:")
        val sorted_k = NN.Inference.top_k(out.1, k)
        for j <- 0:k {
            val (label, prob) = sorted_k[0, j]
            val label_str = if labels != [] {labels[label]} else {f"class_{label}"}
            println(f"\t{j+1}. label={label_str} ({label}), prob={prob}")
        }
    }
    for j <- 0:k {
        val label = tprobs[j].1
        val lbl = if labels != [] {labels[label]} else {f"class_{label}"}
        val prob = tprobs[j].0
        println(f"\t{j+1}. label={lbl} ({label}), prob={prob}")
    }
}

/*val model =
    try NN.FromOnnx.read(mname)
    catch {
    | NN.FromOnnx.OnnxConvertError(msg) =>
        println(f"error: {msg}"); throw Fail("")
    | Fail(msg) =>
        println(f"error: {msg}"); throw Fail("")
    }
println(f"dumping model '{mname}'")
val model = NN.BufferAllocator.assign_buffers(model)
println(model)
*/

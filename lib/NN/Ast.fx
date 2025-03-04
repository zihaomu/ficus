/*
    This file is a part of ficus language project.
    See ficus/LICENSE for the licensing terms
*/

// Deep Models description

import Hashmap

exception NNError: string

type nntyp_t =
    | NN_Undefined | NN_I8 | NN_U8 | NN_I16 | NN_U16 | NN_I32 | NN_U32
    | NN_I64 | NN_U64 | NN_FP16 | NN_BF16 | NN_FP32 | NN_FP64 | NN_Bool

// please, keep the set and the order of tags here equivalent to nntyp_t,
// because some C code may assume nntyp_t::tag == nndata_t::tag.
class nndata_t =
    | NN_Data_Empty
    | NN_Data_I8: int8 []
    | NN_Data_U8: uint8 []
    | NN_Data_I16: int16 []
    | NN_Data_U16: uint16 []
    | NN_Data_I32: int32 []
    | NN_Data_U32: uint32 []
    | NN_Data_I64: int64 []
    | NN_Data_U64: uint64 []
    | NN_Data_Stub_FP16
    | NN_Data_Stub_BF16
    | NN_Data_FP32: float []
    | NN_Data_FP64: double []
    | NN_Data_Bool: bool []

type nnargkind_t =
    | NN_Arg_Const
    | NN_Arg_Input
    | NN_Arg_Output
    | NN_Arg_Temp

type nnlayout_t =
    | NN_Layout_Unknown
    | NN_Layout_NC
    | NN_Layout_NCHW
    | NN_Layout_NHWC
    | NN_Layout_NCHWxc

type nnpadding_t =
    | NN_Pad_None
    | NN_Pad_SameUpper
    | NN_Pad_SameLower
    | NN_Pad_Valid

type nnpooling_t =
    | NN_Pool_Avg
    | NN_Pool_Max

type nnbuf_t = uint8 []

class nnshape_t
{
    layout: nnlayout_t
    shape: int []
}

class nntensor_t
{
    shape: nnshape_t
    data: nndata_t
}

class nnarg_t
{
    name: string
    argkind: nnargkind_t
    shape: nnshape_t
    typ: nntyp_t
}

type nnelwise_t =
    | NN_Abs | NN_Acos | NN_Acosh | NN_Asin | NN_Asinh | NN_Atan | NN_Atanh
    | NN_Ceil | NN_Cos | NN_Cosh | NN_Erf | NN_Exp | NN_Floor | NN_IsInf | NN_IsNaN | NN_Log
    | NN_Neg | NN_Not | NN_Relu | NN_Round | NN_Sigmoid | NN_Sign | NN_Sin | NN_Sinh
    | NN_Softplus | NN_Softsign | NN_Sqrt | NN_Tan | NN_Tanh
    | NN_Add | NN_And | NN_Div | NN_Equal | NN_Greater | NN_GreaterOrEqual
    | NN_Less | NN_LessOrEqual | NN_Mod | NN_Mul | NN_Pow | NN_Or | NN_Sub | NN_Xor
    | NN_Min | NN_Max | NN_Mean

type nnreduce_t =
    | NN_ReduceMin | NN_ReduceMax | NN_ReduceMean
    | NN_ReduceL1 | NN_ReduceL2
    | NN_ReduceLogSum | NN_ReduceLogSumExp
    | NN_ReduceProd | NN_ReduceSum | NN_ReduceSumSquare

type nnorder_t =
    | NN_RowMajor
    | NN_ColumnMajor

type nncoord_trans_t =
    | NN_CT_HalfPixel
    | NN_CT_PyTorchHalfPixel
    | NN_CT_AlignCorners
    | NN_CT_Asymmetric
    | NN_CT_TFCropResize
    | NN_CT_OutHalfPixel

type nninterpolation_t =
    | NN_Inter_Nearest
    | NN_Inter_Linear
    | NN_Inter_Cubic

type dlnearest_mode_t =
    | NN_Nearest_RoundPreferFloor
    | NN_Nearest_RoundPreferCeil
    | NN_Nearest_Floor
    | NN_Nearest_Ceil

type nnconv_attr_t
{
    kernel_shape: int []
    pads: int []
    strides: int []
    dilations: int []
    group: int
}

class nnop_t =
    | NN_Nop
    | NN_AvgPool: {
        name: string
        ceil_mode: bool
        dilations: int []
        kernel_shape: int []
        pads: int []
        strides: int []
        count_include_pad: bool
        t_inp: int; t_out: int }
    | NN_BatchNorm: {
        name: string
        epsilon: float
        momentum: float
        training_mode: bool
        t_inp: int; t_scale: int; t_B: int
        t_mean: int; t_var: int; t_out: int }
    | NN_Cast: {
        name: string; to: nntyp_t; t_inp: int; t_out: int }
    | NN_Clip: {
        name: string; t_inp: int; t_min: int; t_max: int; t_out: int }
    | NN_Concat: {
        name: string; axis: int; t_inp: int []; t_out: int }
    | NN_ConstantOfShape: {
        name: string; value: nntensor_t; t_shape: int; t_out: int }
    | NN_Conv: {
        name: string
        attr: nnconv_attr_t
        conv_data: cptr ref
        fused_batch_norm: nnop_t?
        non_const_batch_norm: bool
        fused_activ: nnop_t?
        non_const_activ: bool
        t_inp: int; t_weights: int
        t_bias: int; t_out: int
        t_passby: int }
    | NN_ConvTranspose: {
        name: string
        kernel_shape: int []
        pads: int []
        strides: int []
        dilations: int []
        out_shape: int []
        out_padding: int []
        group: int
        t_inp: int; t_weights: int; t_bias: int; t_out: int }
    | NN_Dropout: {
        name: string; seed: int = 0
        t_inp: int; t_ratio: int; t_training_mode: int; t_out: int }
    | NN_Elemwise: {
        name: string; el_op: nnelwise_t; t_inp: int []; t_out: int }
    | NN_Expand: {
        name: string; t_inp: int; t_shape: int; t_out: int }
    | NN_Flatten: {
        name: string; axis: int; t_inp: int; t_out: int }
    | NN_Gather: {
        name: string; axis: int; t_inp: int; t_ind: int; t_out: int }
    | NN_Gemm: {
        name: string
        alpha: float = 1.f
        beta: float = 1.f
        transA: bool = false
        transB: bool = false
        t_A: int; t_B: int; t_bias: int; t_out: int }
    | NN_GlobalAvgPool: {
        name: string; t_inp: int; t_out: int }
    | NN_Identity: {
        name: string; t_inp: int; t_out: int }
    | NN_If: {
        name: string; then_branch: nngraph_t; else_branch: nngraph_t; t_inp: int; t_out: int [] }
    | NN_LeakyRelu: {
        name: string; alpha: float; t_inp: int; t_out: int }
    | NN_Loop: {
        name: string; body: nngraph_t; t_trip_count: int;
        t_cond_in: int; t_v_in: int [];
        t_cond_out: int; t_v_out: int [] }
    | NN_LRN: {
        name: string; size: int; alpha: float
        beta: float; bias: float
        t_inp: int; t_out: int }
    | NN_MaxPool: {
        name: string
        ceil_mode: bool
        dilations: int []
        kernel_shape: int []
        pads: int []
        strides: int []
        storage_order: nnorder_t = NN_RowMajor
        t_inp: int; t_out: int }
    | NN_NonMaxSuppression: {
        name: string
        center_point_box: bool;
        t_boxes: int;
        t_scores: int;
        t_max_output_boxes_per_class: int;
        t_iou_threshold: int;
        t_score_threshold: int;
        t_out: int }
    | NN_NonZero: {
        name: string; t_inp: int; t_out: int }
    | NN_Range: {
        name: string; t_start: int; t_limit: int; t_delta: int; t_out: int }
    | NN_Reduce: {
        name: string; reduce_op: nnreduce_t; axes: int []; keepdims: bool; t_inp: int; t_out: int }
    | NN_Reshape: {
        name: string; allowzero: bool=false; t_inp: int; t_shape: int; t_out: int }
    | NN_Resize: {
        name: string
        coord_trans: nncoord_trans_t
        cubic_coeff_a: float
        exclude_outside: bool
        extrapolation_value: float
        mode: nninterpolation_t
        nearest_mode: dlnearest_mode_t
        t_inp: int; t_scales: int; t_sizes: int
        t_roi: int; t_out: int }
    | NN_RoiAlign: {
        name: string
        coord_trans: nncoord_trans_t;
        mode: nnpooling_t;
        output_height: int; output_width: int;
        sampling_ratio: int; spatial_scale: float;
        t_inp: int; t_rois: int; t_batch_ind: int; t_out: int }
    | NN_Scatter: {
        name: string; axis: int; t_data: int; t_updates: int; t_indices: int; t_out: int }
    | NN_Shape: {
        name: string; start: int; end: int; t_inp: int; t_out: int }
    | NN_Slice: {
        name: string; t_inp: int; t_starts: int; t_ends: int; t_axes: int; t_steps: int; t_out: int }
    | NN_SoftMax: {
        name: string; axis: int=-1; t_inp: int; t_out: int }
    | NN_Split: {
        name: string; axis: int; t_inp: int; t_split: int; t_out: int [] }
    | NN_Squeeze: {
        name: string; t_inp: int; t_axes: int; t_out: int }
    | NN_Tile: {
        name: string; t_inp: int; t_repeats: int; t_out: int }
    | NN_TopK: {
        name: string; axis: int; largest: bool; sorted: bool; t_inp: int; t_K: int; t_out: int; t_out_ind: int }
    | NN_Transpose: {
        name: string; perm: int []; t_inp: int; t_out: int }
    | NN_Unsqueeze: {
        name: string; t_inp: int; t_axes: int; t_out: int }

type nnnames_t = (string, int) Hashmap.t

type nnonnx_t =
{
    ir_version: int64
    producer: string
    domain: string
    doc_string: string
    opsets: (int64, string) list
}

type dlnet_info_t =
    | NN_Net_Generic
    | NN_Net_Onnx : nnonnx_t

class nngraph_t =
NN_Graph: {
    inpargs: int []
    outargs: int []
    prog: nnop_t []
}

class nnet_t
{
    info: dlnet_info_t
    argnames: nnnames_t
    dimnames: nnnames_t
    dimnames_: string []
    args: nnarg_t []
    tensors: nntensor_t []
    bufidxs: int []
    buffers: nnbuf_t []
    graph: nngraph_t
    preferred_layout: nnlayout_t
    ntasks: int ref
    use_f16: bool ref
}

type op_callback_t = (nnet_t, nnop_t) -> void

fun empty_net() = nnet_t {
    info = NN_Net_Generic,
    argnames = Hashmap.empty(8, "", 0),
    dimnames = Hashmap.empty(8, "", 0),
    dimnames_ = [],
    args = [],
    tensors = [],
    bufidxs = [],
    buffers = [],
    graph = NN_Graph {inpargs = [], outargs = [], prog=[]},
    preferred_layout = NN_Layout_NCHW,
    ntasks = ref 4,
    use_f16 = ref false
}

fun empty_graph() = NN_Graph {
    inpargs = [],
    outargs = [],
    prog = []
}

fun string(order: nnorder_t)
{
    | NN_RowMajor => "RowMajor"
    | NN_ColumnMajor => "ColumnMajor"
}

fun string(layout: nnlayout_t)
{
    | NN_Layout_Unknown => "Unknown"
    | NN_Layout_NC => "NC"
    | NN_Layout_NCHW => "NCHW"
    | NN_Layout_NHWC => "NHWC"
    | NN_Layout_NCHWxc => "NCHWxc"
}

fun string(p: nnargkind_t) {
    | NN_Arg_Const => "const"
    | NN_Arg_Input => "inp"
    | NN_Arg_Output => "out"
    | NN_Arg_Temp => "temp"
}

fun string(ew: nnelwise_t)
{
    | NN_Abs => "Abs"
    | NN_Acos => "Acos"
    | NN_Acosh => "Acosh"
    | NN_Asin => "Asin"
    | NN_Asinh => "Asinh"
    | NN_Atan => "Atan"
    | NN_Atanh => "Atanh"
    | NN_Ceil => "Ceil"
    | NN_Cos => "Cos"
    | NN_Cosh => "Cosh"
    | NN_Erf => "Erf"
    | NN_Exp => "Exp"
    | NN_Floor => "Floor"
    | NN_IsInf => "IsInf"
    | NN_IsNaN => "IsNaN"
    | NN_Log => "Log"
    | NN_Neg => "Neg"
    | NN_Not => "Not"
    | NN_Relu => "Relu"
    | NN_Round => "Round"
    | NN_Sigmoid => "Sigmoid"
    | NN_Sign => "Sign"
    | NN_Sin => "Sin"
    | NN_Sinh => "Sinh"
    | NN_Softplus => "Softplus"
    | NN_Softsign => "Softsign"
    | NN_Sqrt => "Sqrt"
    | NN_Tan => "Tan"
    | NN_Tanh => "Tanh"

    | NN_Add => "Add"
    | NN_And => "And"
    | NN_Div => "Div"
    | NN_Equal => "Equal"
    | NN_Greater => "Greater"
    | NN_GreaterOrEqual => "GreaterOrEqual"
    | NN_Less => "Less"
    | NN_LessOrEqual => "LessOrEqual"
    | NN_Mod => "Mod"
    | NN_Mul => "Mul"
    | NN_Or => "Or"
    | NN_Pow  => "Pow"
    | NN_Sub => "Sub"
    | NN_Xor => "Xor"

    | NN_Min => "Min"
    | NN_Max => "Max"
    | NN_Mean => "Mean"
}

fun string(r: nnreduce_t)
{
    | NN_ReduceMin => "ReduceMin"
    | NN_ReduceMax => "ReduceMax"
    | NN_ReduceMean => "ReduceMean"
    | NN_ReduceL1 => "ReduceL1"
    | NN_ReduceL2 => "ReduceL2"
    | NN_ReduceLogSum => "ReduceLogSum"
    | NN_ReduceLogSumExp => "ReduceLogSumExp"
    | NN_ReduceProd => "ReduceProd"
    | NN_ReduceSum => "ReduceSum"
    | NN_ReduceSumSquare => "ReduceSumSquare"
}

fun string(p: nnpadding_t) {
    | NN_Pad_None => "NoPadding"
    | NN_Pad_SameUpper => "Pad_SameUpper"
    | NN_Pad_SameLower => "Pad_SameLower"
    | NN_Pad_Valid => "Pad_Valid"
}

fun string(interpolation: nninterpolation_t)
{
    | NN_Inter_Nearest => "Nearest"
    | NN_Inter_Linear => "Linear"
    | NN_Inter_Cubic => "Cubic"
}

fun string(coord_trans: nncoord_trans_t)
{
    | NN_CT_HalfPixel => "HalfPixel"
    | NN_CT_PyTorchHalfPixel => "PyTorchHalfPixel"
    | NN_CT_AlignCorners => "AlignCorners"
    | NN_CT_Asymmetric => "Asymmetric"
    | NN_CT_TFCropResize => "TFCropResize"
    | NN_CT_OutHalfPixel => "OutputHalfPixel"
}

fun string(nearest_round: dlnearest_mode_t)
{
    | NN_Nearest_RoundPreferFloor => "Nearest_RoundPreferFloor"
    | NN_Nearest_RoundPreferCeil => "Nearest_RoundPreferCeil"
    | NN_Nearest_Ceil => "Nearest_Ceil"
    | NN_Nearest_Floor => "Nearest_Floor"
}

fun string(mode: nnpooling_t)
{
    | NN_Pool_Max => "MaxPooling"
    | NN_Pool_Avg => "AveragePooling"
}

fun nndata_t.total() =
match self {
    | NN_Data_Empty
    | NN_Data_Stub_FP16 | NN_Data_Stub_BF16 => 0
    | NN_Data_I8(elems) => size(elems)
    | NN_Data_U8(elems) => size(elems)
    | NN_Data_I16(elems) => size(elems)
    | NN_Data_U16(elems) => size(elems)
    | NN_Data_I32(elems) => size(elems)
    | NN_Data_U32(elems) => size(elems)
    | NN_Data_I64(elems) => size(elems)
    | NN_Data_U64(elems) => size(elems)
    | NN_Data_FP32(elems) => size(elems)
    | NN_Data_FP64(elems) => size(elems)
    | NN_Data_Bool(elems) => size(elems)
}

fun nntensor_t.total() =
match self.data {
    | NN_Data_Empty
    | NN_Data_Stub_FP16 | NN_Data_Stub_BF16 => 0
    | NN_Data_I8(elems) => size(elems)
    | NN_Data_U8(elems) => size(elems)
    | NN_Data_I16(elems) => size(elems)
    | NN_Data_U16(elems) => size(elems)
    | NN_Data_I32(elems) => size(elems)
    | NN_Data_U32(elems) => size(elems)
    | NN_Data_I64(elems) => size(elems)
    | NN_Data_U64(elems) => size(elems)
    | NN_Data_FP32(elems) => size(elems)
    | NN_Data_FP64(elems) => size(elems)
    | NN_Data_Bool(elems) => size(elems)
}

fun float(d: nndata_t)
{
    | NN_Data_Empty
    | NN_Data_Stub_FP16 | NN_Data_Stub_BF16 => ([] : float [])
    | NN_Data_I8(elems) => float(elems)
    | NN_Data_U8(elems) => float(elems)
    | NN_Data_I16(elems) => float(elems)
    | NN_Data_U16(elems) => float(elems)
    | NN_Data_I32(elems) => float(elems)
    | NN_Data_U32(elems) => float(elems)
    | NN_Data_I64(elems) => float(elems)
    | NN_Data_U64(elems) => float(elems)
    | NN_Data_FP32(elems) => elems
    | NN_Data_FP64(elems) => float(elems)
    | NN_Data_Bool(elems) => float(elems)
}

fun float_scalar_or(d: nndata_t, defval: float): float =
match d {
    | NN_Data_Empty => defval
    | NN_Data_Stub_FP16 | NN_Data_Stub_BF16 => throw Fail("FP16 is not supported yet")
    | NN_Data_I8(elems) => float(elems[0])
    | NN_Data_U8(elems) => float(elems[0])
    | NN_Data_I16(elems) => float(elems[0])
    | NN_Data_U16(elems) => float(elems[0])
    | NN_Data_I32(elems) => float(elems[0])
    | NN_Data_U32(elems) => float(elems[0])
    | NN_Data_I64(elems) => float(elems[0])
    | NN_Data_U64(elems) => float(elems[0])
    | NN_Data_FP32(elems) => elems[0]
    | NN_Data_FP64(elems) => float(elems[0])
    | NN_Data_Bool(elems) => float(elems[0])
}

fun double(d: nndata_t)
{
    | NN_Data_Empty
    | NN_Data_Stub_FP16 | NN_Data_Stub_BF16 => ([] : double [])
    | NN_Data_I8(elems) => double(elems)
    | NN_Data_U8(elems) => double(elems)
    | NN_Data_I16(elems) => double(elems)
    | NN_Data_U16(elems) => double(elems)
    | NN_Data_I32(elems) => double(elems)
    | NN_Data_U32(elems) => double(elems)
    | NN_Data_I64(elems) => double(elems)
    | NN_Data_U64(elems) => double(elems)
    | NN_Data_FP32(elems) => double(elems)
    | NN_Data_FP64(elems) => elems
    | NN_Data_Bool(elems) => double(elems)
}

fun int(d: nndata_t)
{
    | NN_Data_Empty
    | NN_Data_Stub_FP16 | NN_Data_Stub_BF16 => ([] : int [])
    | NN_Data_I8(elems) => int(elems)
    | NN_Data_U8(elems) => int(elems)
    | NN_Data_I16(elems) => int(elems)
    | NN_Data_U16(elems) => int(elems)
    | NN_Data_I32(elems) => int(elems)
    | NN_Data_U32(elems) => int(elems)
    | NN_Data_I64(elems) => int(elems)
    | NN_Data_U64(elems) => int(elems)
    | NN_Data_FP32(elems) => int(elems)
    | NN_Data_FP64(elems) => int(elems)
    | NN_Data_Bool(elems) => int(elems)
}

fun float(t: nntensor_t) = float(t.data)
fun double(t: nntensor_t) = double(t.data)
fun int(t: nntensor_t) = int(t.data)

fun arr2str(elems: 't []) = join_embrace("[", "]", ",", elems.map(repr))

fun tdata2str(d: nndata_t)
{
    | NN_Data_Empty
    | NN_Data_Stub_FP16 | NN_Data_Stub_BF16 => "[]"
    | NN_Data_I8(elems) => arr2str(elems)
    | NN_Data_U8(elems) => arr2str(elems)
    | NN_Data_I16(elems) => arr2str(elems)
    | NN_Data_U16(elems) => arr2str(elems)
    | NN_Data_I32(elems) => arr2str(elems)
    | NN_Data_U32(elems) => arr2str(elems)
    | NN_Data_I64(elems) => arr2str(elems)
    | NN_Data_U64(elems) => arr2str(elems)
    | NN_Data_FP32(elems) => arr2str(elems)
    | NN_Data_FP64(elems) => arr2str(elems)
    | NN_Data_Bool(elems) => arr2str(elems)
}

fun string(typ: nntyp_t)
{
    | NN_Undefined => "Undefined"
    | NN_I8 => "I8"
    | NN_U8 => "U8"
    | NN_I16 => "I16"
    | NN_U16 => "U16"
    | NN_I32 => "I32"
    | NN_U32 => "U32"
    | NN_I64 => "I64"
    | NN_U64 => "U64"
    | NN_FP16 => "FP16"
    | NN_BF16 => "BF16"
    | NN_FP32 => "FP32"
    | NN_FP64 => "FP64"
    | NN_Bool => "Bool"
}

fun dim2str(net: nnet_t, d: int) = if d > 0 {string(d)} else if d == 0 {"?"} else {net.dimnames_[-d-1]}

fun shape2str(net: nnet_t, s: nnshape_t)
{
    val shape_str = " x ".join([for d <- s.shape {dim2str(net, d)}])
    (match (s.layout, size(s.shape)) {
    | (NN_Layout_Unknown, _) => ""
    | (_, dims) when dims > 1 => f"{s.layout} "
    | _ => ""
    }) + f"<{shape_str}>"
}

fun nndata_t.elemtype() =
match self {
    | NN_Data_Empty => NN_Undefined
    | NN_Data_I8 _ => NN_I8
    | NN_Data_U8 _ => NN_U8
    | NN_Data_I16 _ => NN_I16
    | NN_Data_U16 _ => NN_U16
    | NN_Data_I32 _ => NN_I32
    | NN_Data_U32 _ => NN_U32
    | NN_Data_I64 _ => NN_I64
    | NN_Data_U64 _ => NN_U64
    | NN_Data_Stub_FP16 => NN_FP16
    | NN_Data_Stub_BF16 => NN_BF16
    | NN_Data_FP32 _ => NN_FP32
    | NN_Data_FP64 _ => NN_FP64
    | NN_Data_Bool _ => NN_Bool
}

fun nntensor_t.elemtype() =
match self.data {
    | NN_Data_Empty => NN_Undefined
    | NN_Data_I8 _ => NN_I8
    | NN_Data_U8 _ => NN_U8
    | NN_Data_I16 _ => NN_I16
    | NN_Data_U16 _ => NN_U16
    | NN_Data_I32 _ => NN_I32
    | NN_Data_U32 _ => NN_U32
    | NN_Data_I64 _ => NN_I64
    | NN_Data_U64 _ => NN_U64
    | NN_Data_Stub_FP16 => NN_FP16
    | NN_Data_Stub_BF16 => NN_BF16
    | NN_Data_FP32 _ => NN_FP32
    | NN_Data_FP64 _ => NN_FP64
    | NN_Data_Bool _ => NN_Bool
}

fun tensor2str(net: nnet_t, t: nntensor_t, show_small: bool) =
match t.data {
    | NN_Data_Empty => "[]"
    | _ =>
        val sp = shape2str(net, t.shape)
        val tprefix = string(t.elemtype())
        val nelems = t.total()
        val tdata_str = if nelems <= 10 && show_small {tdata2str(t.data)} else {"[...]"}
        sp + " " + tprefix + " " + tdata_str
}

fun arg2str(net: nnet_t, argidx: int)
{
    val targ = net.args[argidx]
    val sp = shape2str(net, targ.shape)
    val cprefix = match targ.argkind { NN_Arg_Temp => "" | _ => string(targ.argkind) + " " }
    val (tdatastr, bufstr) = match targ {
        | {argkind=NN_Arg_Const, shape={shape}}
            when argidx > 0 && size(shape) == 1 && shape[0] < 10 =>
            (": " + tdata2str(net.tensors[argidx].data), "")
        | {argkind=NN_Arg_Temp} => ("", f" (buf #{net.bufidxs[argidx]})")
        | _ => ("", "")
    }
    cprefix + sp + " " + string(targ.typ) + tdatastr + bufstr
}

fun parse_params(params: string): string list
{
    var paren_stack: char list = []
    fun issep(c: char) = match (c, paren_stack) {
        | ('(', _) | ('[', _) | ('{', _) => paren_stack = c :: paren_stack; false
        | (')', '(' :: rest) => paren_stack = rest; false
        | (']', '[' :: rest) => paren_stack = rest; false
        | ('}', '{' :: rest) => paren_stack = rest; false
        | (')', _) | (']', _) | ('}', _) =>
            throw Fail("unexpected closing ')', ']' or '}' in the parameters")
        | (',', []) => true
        | _ => false
    }
    params.tokens(issep).map(String.strip)
}

fun op2str(name: string, opname: string, params: string, tensors: string [], indent0: string)
{
    val indent = indent0 + "   "
    val pl = parse_params(params)
    val pprefix = if pl == [] {""} else {f"\n{indent}"}
    join_embrace(f"{opname} {{\n{indent}name=\"{name}\",\n{indent}",
        join_embrace(pprefix, f"\n{indent0}}}", f",\n{indent}", pl),
        f"\n{indent}", tensors)
}

fun graph2str(net: nnet_t, graph: nngraph_t, indent: string)
{
    val {inpargs, outargs, prog} = graph
    val new_indent = indent + "  "
    val prog_indent = new_indent + "  "
    val inpstrs = [for a <- inpargs {net.args[a].name}]
    val outstrs = [for a <- outargs {net.args[a].name}]
    val prog = [for op@i <- prog {
        f"{indent}// op #{i}\n{prog_indent}" + op2str(net, op, prog_indent)}]
    join_embrace(f"graph {{\n{new_indent}inputs={inpstrs},\n\
        {new_indent}outputs={outstrs},\n{new_indent}prog={{\n{prog_indent}",
        f"\n{new_indent}}}\n{indent}}}",
        f",\n{prog_indent}", prog)
}

fun nnop_t.name(): (string, string) = match self
{
    | NN_Nop => ("", "Nop")
    | NN_AvgPool {name} => (name, "AvgPool")
    | NN_BatchNorm {name} => (name, "BatchNorm")
    | NN_Cast {name} => (name, "Cast")
    | NN_Clip {name} => (name, "Clip")
    | NN_Concat {name} => (name, "Concat")
    | NN_ConstantOfShape {name} => (name, "ConstantOfShape")
    | NN_Conv {name} => (name, "Conv")
    | NN_ConvTranspose {name} => (name, "ConvTranspose")
    | NN_Dropout {name} => (name, "Dropout")
    | NN_Elemwise {name, el_op} => (name, string(el_op))
    | NN_Expand {name} => (name, "Expand")
    | NN_Flatten {name} => (name, "Flatten")
    | NN_Gather {name} => (name, "Gather")
    | NN_Gemm {name} => (name, "Gemm")
    | NN_GlobalAvgPool {name} => (name, "GlobalAvgPool")
    | NN_Identity {name} => (name, "Identity")
    | NN_If {name} => (name, "If")
    | NN_LeakyRelu {name} => (name, "LeakyRelu")
    | NN_Loop {name} => (name, "Loop")
    | NN_LRN {name} => (name, "LRN")
    | NN_MaxPool {name} => (name, "MaxPool")
    | NN_NonMaxSuppression {name} => (name, "NonMaxSuppression")
    | NN_NonZero {name} => (name, "NonZero")
    | NN_Range {name} => (name, "Range")
    | NN_Reduce {name, reduce_op} => (name, string(reduce_op))
    | NN_Resize {name} => (name, "Resize")
    | NN_Reshape {name} => (name, "Reshape")
    | NN_RoiAlign {name} => (name, "RoiAlign")
    | NN_Scatter {name} => (name, "Scatter")
    | NN_Shape {name} => (name, "Shape")
    | NN_Slice {name} => (name, "Slice")
    | NN_SoftMax {name} => (name, "SoftMax")
    | NN_Split {name} => (name, "Split")
    | NN_Squeeze {name} => (name, "Squeeze")
    | NN_Tile {name} => (name, "Tile")
    | NN_TopK {name} => (name, "TopK")
    | NN_Transpose {name} => (name, "Transpose")
    | NN_Unsqueeze {name} => (name, "Unsqueeze")
}

fun targs2pairs(prefix: string, args: int []) =
    if args.size() == 1 {[(prefix, args[0])]}
    else {[for a@i <- args {(f"{prefix}{i}", a)}]}

fun t2str(net: nnet_t, tensors: (string, int) []) =
    [for (name, tidx) <- tensors {
        val targ = if tidx >= 0 {net.args[tidx]} else {empty_arg()}
        f"{name}=\"{targ.name}\", // {arg2str(net, tidx)}"
    }]

fun nnop_t.get_inputs_outputs(): (int [], int []) = match self
{
    | NN_Nop => ([], [])
    | NN_AvgPool {t_inp, t_out} => ([t_inp], [t_out])
    | NN_BatchNorm {t_inp, t_scale, t_B, t_mean, t_var, t_out} => ([t_inp, t_scale, t_B, t_mean, t_var], [t_out])
    | NN_Cast {t_inp, t_out} => ([t_inp], [t_out])
    | NN_Clip {t_inp, t_min, t_max, t_out} => ([t_inp, t_min, t_max], [t_out])
    | NN_Concat {t_inp, t_out} => (t_inp, [t_out])
    | NN_ConstantOfShape {t_shape, t_out} => ([t_shape], [t_out])
    | NN_Conv {t_inp, t_weights, t_bias, t_out, t_passby} => ([t_inp, t_weights, t_bias, t_passby], [t_out])
    | NN_ConvTranspose {t_inp, t_weights, t_bias, t_out} => ([t_inp, t_weights, t_bias], [t_out])
    | NN_Dropout {t_inp, t_ratio, t_training_mode, t_out} => ([t_inp, t_ratio, t_training_mode], [t_out])
    | NN_Elemwise {t_inp, t_out} => (t_inp, [t_out])
    | NN_Expand {t_inp, t_shape, t_out} => ([t_inp, t_shape], [t_out])
    | NN_Flatten {t_inp, t_out} => ([t_inp], [t_out])
    | NN_Gather {t_inp, t_ind, t_out} => ([t_inp, t_ind], [t_out])
    | NN_Gemm {t_A, t_B, t_bias, t_out} => ([t_A, t_B, t_bias], [t_out])
    | NN_GlobalAvgPool {t_inp, t_out} => ([t_inp], [t_out])
    | NN_Identity {t_inp, t_out} => ([t_inp], [t_out])
    | NN_If {t_inp, t_out} => ([t_inp], t_out)
    | NN_LeakyRelu {t_inp, t_out} => ([t_inp], [t_out])
    | NN_Loop {t_trip_count, t_cond_in, t_v_in, t_cond_out, t_v_out} =>
        ([t_trip_count, t_cond_in, \t_v_in], [t_cond_out, \t_v_out])
    | NN_LRN {t_inp, t_out} => ([t_inp], [t_out])
    | NN_MaxPool {t_inp, t_out} => ([t_inp], [t_out])
    | NN_NonMaxSuppression {t_boxes, t_scores, t_max_output_boxes_per_class,
        t_iou_threshold, t_score_threshold, t_out} =>
            ([t_boxes, t_scores, t_max_output_boxes_per_class, t_iou_threshold, t_score_threshold], [t_out])
    | NN_NonZero {t_inp, t_out} => ([t_inp], [t_out])
    | NN_Range {t_start, t_limit, t_delta, t_out} => ([t_start, t_limit, t_delta], [t_out])
    | NN_Reduce {t_inp, t_out} => ([t_inp], [t_out])
    | NN_Reshape {t_inp, t_shape, t_out} => ([t_inp], [t_out])
    | NN_Resize {t_inp, t_scales, t_sizes, t_roi, t_out} => ([t_inp, t_scales, t_sizes, t_roi], [t_out])
    | NN_RoiAlign {t_inp, t_rois, t_batch_ind, t_out} => ([t_inp, t_rois, t_batch_ind], [t_out])
    | NN_Scatter {t_data, t_updates, t_indices, t_out} => ([t_data, t_updates, t_indices], [t_out])
    | NN_Shape {t_inp, t_out} => ([t_inp], [t_out])
    | NN_Slice {t_inp, t_starts, t_ends, t_axes, t_steps, t_out} => ([t_inp, t_starts, t_ends, t_axes, t_steps], [t_out])
    | NN_SoftMax {t_inp, t_out} => ([t_inp], [t_out])
    | NN_Split {t_inp, t_split, t_out} => ([t_inp, t_split], t_out)
    | NN_Squeeze {t_inp, t_axes, t_out} => ([t_inp, t_axes], [t_out])
    | NN_Tile {t_inp, t_repeats, t_out} => ([t_inp, t_repeats], [t_out])
    | NN_TopK {t_inp, t_K, t_out, t_out_ind} =>  ([t_inp, t_K], [t_out, t_out_ind])
    | NN_Transpose {t_inp, t_out} => ([t_inp], [t_out])
    | NN_Unsqueeze {t_inp, t_axes, t_out} => ([t_inp, t_axes], [t_out])
}

fun op2str(net: nnet_t, op: nnop_t, indent: string): string
{
    val sub_indent = indent + "  "
    //println(f"dumping op={op.name()}")
    match op {
    | NN_Nop => "Nop"
    | NN_AvgPool {name, ceil_mode, dilations, kernel_shape, pads,
        strides, count_include_pad, t_inp, t_out} =>
        op2str(name, "AvgPool", f"ceil_mode={ceil_mode},\ndilations={dilations},\nkernel_shape={kernel_shape},\n\
            pads={pads},\nstrides={strides},\ncount_include_pad={count_include_pad}",
            t2str(net, [("t_inp", t_inp), ("t_out", t_out)]), indent)
    | NN_BatchNorm {name, epsilon, momentum, training_mode, t_inp, t_scale, t_B, t_mean, t_var, t_out} =>
        op2str(name, "BatchNorm", f"epsilon={epsilon},\nmomentum={momentum},\ntraining_mode={training_mode}",
            t2str(net, [("t_inp", t_inp), ("t_scale", t_scale), ("t_B", t_B),
            ("t_mean", t_mean), ("t_var", t_var), ("t_out", t_out)]), indent)
    | NN_Cast {name, to, t_inp, t_out} =>
        op2str(name, "Cast", f"to={to}", t2str(net, [("t_inp", t_inp), ("t_out", t_out)]), indent)
    | NN_Clip {name, t_inp, t_min, t_max, t_out} =>
        op2str(name, "Clip", "", t2str(net, [("t_inp", t_inp), ("t_min", t_min), ("t_max", t_max), ("t_out", t_out)]), indent)
    | NN_Concat {name, axis, t_inp, t_out} =>
        op2str(name, "Concat", f"axis={axis}", t2str(net, [\targs2pairs("t_inp", t_inp), ("t_out", t_out)]), indent)
    | NN_ConstantOfShape {name, value, t_shape, t_out} =>
        op2str(name, "ConstantOfShape", f"value={tensor2str(net, value, true)}",
            t2str(net, [("t_shape", t_shape), ("t_out", t_out)]), indent)
    | NN_Conv {name=convname, attr,
        fused_batch_norm, fused_activ, t_inp, t_weights, t_bias, t_out, t_passby} =>
        val bnorm_name = match fused_batch_norm {
            | Some(NN_BatchNorm _) => " + BatchNorm"
            | _ => ""}
        val activ_name = match fused_activ {
            | Some(activ) =>
                val (_, opname): (string, string) = activ.name()
                " + " + opname
            | _ => ""}
        val (passby_name, passby_attr) =
            if t_passby > 0 {
                (" + Add", f", passby=\"{net.args[t_passby].name}\"")
            } else {("", "")}
        op2str(convname, "Conv" + bnorm_name + passby_name + activ_name, f"kernel_shape={attr.kernel_shape}, \
            pads={attr.pads}, strides={attr.strides}, dilations={attr.dilations}, group={attr.group}{passby_attr}",
            t2str(net, [("t_inp", t_inp), ("t_weights", t_weights), ("t_bias", t_bias), ("t_out", t_out)]), indent)
    | NN_ConvTranspose {name, kernel_shape, pads, strides, dilations, group,
        out_shape, out_padding, t_inp, t_weights, t_bias, t_out} =>
        op2str(name, "Conv", f"kernel_shape={kernel_shape}, \
            pads={pads}, strides={strides}, dilations={dilations}, group={group}, out_padding={out_padding}, out_shape={out_shape}",
            t2str(net, [("t_inp", t_inp), ("t_weights", t_weights), ("t_bias", t_bias), ("t_out", t_out)]), indent)
    | NN_Dropout {name, seed, t_inp, t_ratio, t_training_mode, t_out} =>
        op2str(name, "Dropout", f"seed={seed}", t2str(net,
            [("t_inp", t_inp), ("t_ratio", t_ratio), ("t_training_mode", t_training_mode), ("t_out", t_out)]), indent)
    | NN_Elemwise {name, el_op, t_inp, t_out} =>
        val targs = [\targs2pairs("t_inp", t_inp), ("t_out", t_out)]
        op2str(name, string(el_op), "", t2str(net, targs), indent)
    | NN_Expand {name, t_inp, t_shape, t_out} =>
        op2str(name, "Expand", "", t2str(net, [("t_inp", t_inp), ("t_shape", t_shape), ("t_out", t_out)]), indent)
    | NN_Flatten {name, axis, t_inp, t_out} =>
        op2str(name, "Flatten", f"axis={axis}", t2str(net, [("t_inp", t_inp), ("t_out", t_out)]), indent)
    | NN_Gather {name, axis, t_inp, t_ind, t_out} =>
        op2str(name, "Gather", f"axis={axis}", t2str(net, [("t_inp", t_inp), ("t_ind", t_ind), ("t_out", t_out)]), indent)
    | NN_Gemm {name, alpha, beta, transA, transB, t_A, t_B, t_bias, t_out} =>
        op2str(name, "Gemm", f"alpha={alpha},\nbeta={beta},\ntransA={transA},\ntransB={transB}",
        t2str(net, [("t_A", t_A), ("t_B", t_B), ("t_bias", t_bias), ("t_out", t_out)]), indent)
    | NN_GlobalAvgPool {name, t_inp, t_out} =>
        op2str(name, "GlobalAvgPool", "", t2str(net, [("t_inp", t_inp), ("t_out", t_out)]), indent)
    | NN_Identity {name, t_inp, t_out} =>
        op2str(name, "Identity", "", t2str(net, [("t_inp", t_inp), ("t_out", t_out)]), indent)
    | NN_If {name, then_branch, else_branch, t_inp, t_out} =>
        val then_branch_str = graph2str(net, then_branch, sub_indent)
        val else_branch_str = graph2str(net, else_branch, sub_indent)
        op2str(name, "If", f"then={then_branch_str}, else={else_branch_str}",
            t2str(net, [("t_inp", t_inp)] + targs2pairs("t_out", t_out)), indent)
    | NN_LeakyRelu {name, alpha, t_inp, t_out} =>
        op2str(name, "LeakyRelu", f"alpha={alpha}", t2str(net, [("t_inp", t_inp), ("t_out", t_out)]), indent)
    | NN_Loop {name, body, t_trip_count, t_cond_in, t_v_in, t_cond_out, t_v_out} =>
        val body_str = graph2str(net, body, sub_indent)
        op2str(name, "Loop", f"body={body_str}",
            t2str(net, [("t_trip_count", t_trip_count), ("t_cond_in", t_cond_in),
                \targs2pairs("t_v_in", t_v_in), ("t_cond_out", t_cond_out),
                \targs2pairs("t_v_out", t_v_out)]), indent)
    | NN_LRN {name, size, alpha, beta, bias, t_inp, t_out} =>
        op2str(name, "LRN", f"size={size},\nalpha={alpha},\nbeta={beta},\nbias={bias}",
                t2str(net, [("t_inp", t_inp), ("t_out", t_out)]), indent)
    | NN_MaxPool {name, ceil_mode, dilations, kernel_shape, pads,
        strides, storage_order, t_inp, t_out} =>
        op2str(name, "MaxPool", f"ceil_mode={ceil_mode}, dilations={dilations}, kernel_shape={kernel_shape}, \
            pads={pads}, strides={strides}, storage_order={storage_order}",
            t2str(net, [("t_inp", t_inp), ("t_out", t_out)]), indent)
    | NN_NonMaxSuppression {
        name, center_point_box, t_boxes, t_scores,
        t_max_output_boxes_per_class, t_iou_threshold,
        t_score_threshold, t_out } =>
        op2str(name, "NonMaxSuppression", f"center_point_box={center_point_box}",
            t2str(net, [("t_boxes", t_boxes), ("t_scores", t_scores), ("t_max_output_boxes_per_class", t_max_output_boxes_per_class),
            ("t_iou_threshold", t_iou_threshold), ("t_score_threshold", t_score_threshold), ("t_out", t_out)]), indent)
    | NN_NonZero { name, t_inp, t_out } =>
        op2str(name, "NonZero", "", t2str(net, [("t_inp", t_inp), ("t_out", t_out)]), indent)
    | NN_Range {name, t_start, t_limit, t_delta, t_out} =>
        op2str(name, "Range", "", t2str(net, [("t_start", t_start), ("t_limit", t_limit),
            ("t_delta", t_delta), ("t_out", t_out)]), indent)
    | NN_Reduce {name, reduce_op, axes, keepdims, t_inp, t_out} =>
        op2str(name, string(reduce_op), f"axes={axes}, keepdims={keepdims}",
            t2str(net, [("t_inp", t_inp), ("t_out", t_out)]), indent)
    | NN_Resize { name, coord_trans, cubic_coeff_a, exclude_outside, extrapolation_value,
        mode, nearest_mode, t_inp, t_scales, t_sizes, t_roi, t_out } =>
        val nearest_mode_str = if mode == NN_Inter_Nearest {f", nearest_mode={nearest_mode}"} else {""}
        val tensors = [:: ("t_out", t_out)]
        val tensors = if coord_trans == NN_CT_TFCropResize {("t_roi", t_roi) :: tensors} else {tensors}
        val tensors = if t_scales != 0 {("t_scales", t_scales) :: tensors} else {("t_sizes", t_sizes) :: tensors}
        op2str(name, "Resize", f"coord_trans={coord_trans}, cubic_coeff_a={cubic_coeff_a},\
            exclude_outside={exclude_outside}, extrapolation_value={extrapolation_value},\
            mode={mode}{nearest_mode_str}",
            t2str(net, array(("t_inp", t_inp) :: tensors)), indent)
    | NN_Reshape {name, allowzero, t_inp, t_shape, t_out} =>
        op2str(name, "Reshape", f"allowzero={allowzero}",
            t2str(net, [("t_inp", t_inp), ("t_shape", t_shape), ("t_out", t_out)]), indent)
    | NN_RoiAlign {name, coord_trans, mode, output_height, output_width,
        sampling_ratio, spatial_scale, t_inp, t_rois, t_batch_ind, t_out} =>
        op2str(name, "RoiAlign", f"coord_trans={coord_trans}, pooling_mode={mode},\
            output_height={output_height}, output_width={output_width},\
            sampling_ratio={sampling_ratio}, sampling_ratio={sampling_ratio}",
            t2str(net, [("t_inp", t_inp), ("t_rois", t_rois), ("t_batch_ind", t_batch_ind), ("t_out", t_out)]), indent)
    | NN_Scatter {name, axis, t_data, t_updates, t_indices, t_out} =>
        op2str(name, "Scatter", f"axis={axis}",
            t2str(net, [("t_data", t_data), ("t_updates", t_updates), ("t_indices", t_indices), ("t_out", t_out)]), indent)
    | NN_Shape {name, start, end, t_inp, t_out} =>
        op2str(name, "Shape", f"start={start}, end={end}",
            t2str(net, [("t_data", t_inp), ("t_shape", t_out)]), indent)
    | NN_Slice {name, t_inp, t_starts, t_ends, t_axes, t_steps, t_out} =>
        op2str(name, "Slice", "", t2str(net, [("t_inp", t_inp), ("t_starts", t_starts),
            ("t_ends", t_ends), ("t_axes", t_axes), ("t_steps", t_steps), ("t_out", t_out)]), indent)
    | NN_SoftMax {name, axis, t_inp, t_out } =>
        op2str(name, "SoftMax", f"axis={axis}", t2str(net, [("t_inp", t_inp), ("t_out", t_out)]), indent)
    | NN_Split {name, axis, t_inp, t_split, t_out} =>
        op2str(name, "Split", f"axis={axis}", t2str(net, [("t_inp", t_inp), ("t_split", t_split)] + targs2pairs("t_out", t_out)), indent)
    | NN_Squeeze {name, t_inp, t_axes, t_out} =>
        op2str(name, "Squeeze", "", t2str(net, [("t_inp", t_inp), ("t_axes", t_axes), ("t_out", t_out)]), indent)
    | NN_Tile {name, t_inp, t_repeats, t_out} =>
        op2str(name, "Tile", "", t2str(net, [("t_inp", t_inp), ("t_repeats", t_repeats), ("t_out", t_out)]), indent)
    | NN_TopK {name, axis, largest, sorted, t_inp, t_K, t_out, t_out_ind} =>
        op2str(name, "TopK", f"axis={axis}, largest={largest}, sorted={sorted}",
            t2str(net, [("t_inp", t_inp), ("t_K", t_K), ("t_out", t_out), ("t_out_ind", t_out_ind)]), indent)
    | NN_Transpose {name, perm, t_inp, t_out} =>
        op2str(name, "Tranpose", f"perm={perm}", t2str(net, [("t_inp", t_inp), ("t_out", t_out)]), indent)
    | NN_Unsqueeze {name, t_inp, t_axes, t_out} =>
        op2str(name, "Unsqueeze", "", t2str(net, [("t_inp", t_inp), ("t_axes", t_axes), ("t_out", t_out)]), indent)
    }
}

fun string(info: dlnet_info_t) {
    | NN_Net_Generic => "Generic_Net {}"
    | NN_Net_Onnx(onnx) =>
        val opsets=
            if onnx.opsets == [] {"[]"}
            else {
                join_embrace("[\n       ", "\n    ]", ",\n        ",
                    [:: for (ver, domain) <- onnx.opsets {f"\"{domain} v{ver}\""}])
            }
        f"Imported_from_Onnx {{
    ir_version={onnx.ir_version},
    producer=\"{onnx.producer}\",
    domain=\"{onnx.domain}\",
    doc_string=\"{onnx.doc_string}\",
    opsets={opsets}
}}"
}

fun print(net: nnet_t)
{
    match net.info {
    | NN_Net_Generic => {}
    | _ => println(string(net.info))
    }
    println(graph2str(net, net.graph, ""))
}

fun elemsize(t: nntyp_t)
{
    | NN_Undefined => -1
    | NN_I8 | NN_U8 | NN_Bool => 1
    | NN_I16 | NN_U16 | NN_FP16 | NN_BF16 => 2
    | NN_I32 | NN_U32 | NN_FP32 => 4
    | NN_I64 | NN_U64 | NN_FP64 => 8
}

fun nndata_t.copy() =
match self {
    | NN_Data_Empty | NN_Data_Stub_FP16 | NN_Data_Stub_BF16 => NN_Data_Empty
    | NN_Data_I8(arr) => NN_Data_I8(copy(arr))
    | NN_Data_U8(arr) => NN_Data_U8(copy(arr))
    | NN_Data_I16(arr) => NN_Data_I16(copy(arr))
    | NN_Data_U16(arr) => NN_Data_U16(copy(arr))
    | NN_Data_I32(arr) => NN_Data_I32(copy(arr))
    | NN_Data_U32(arr) => NN_Data_U32(copy(arr))
    | NN_Data_I64(arr) => NN_Data_I64(copy(arr))
    | NN_Data_U64(arr) => NN_Data_U64(copy(arr))
    | NN_Data_FP32(arr) => NN_Data_FP32(copy(arr))
    | NN_Data_FP64(arr) => NN_Data_FP64(copy(arr))
    | NN_Data_Bool(arr) => NN_Data_Bool(copy(arr))
}

fun empty_shape() = nnshape_t {
    layout = NN_Layout_Unknown,
    shape = []
}

fun empty_tensor() = nntensor_t {
    shape = empty_shape(),
    data = NN_Data_Empty
}

fun empty_arg() = nnarg_t {
    name = "",
    argkind = NN_Arg_Temp,
    shape = empty_shape(),
    typ = NN_Undefined
}

fun nnshape_t.total() = fold p=1 for sz <- self.shape {p*sz}

fun nnshape_t.copy() = nnshape_t {
    layout = self.layout,
    shape = self.shape.copy()
}

fun nnshape_t.get_num_channels()
{
    val ndims = self.shape.size()
    match (self.layout, ndims) {
    | (_, 1) => self.shape[0]
    | (NN_Layout_NC, _) => self.shape[1]
    | (NN_Layout_NCHW, _) => self.shape[1]
    | (NN_Layout_NHWC, _) => self.shape[ndims-1]
    | (NN_Layout_NCHWxc, _) => self.shape[1]*self.shape[ndims-1]
    | _ => -1
    }
}

fun nnshape_t.get_spatial_channel_range()
{
    val ndims = self.shape.size()
    match self.layout {
    | NN_Layout_NCHW => (2, ndims)
    | NN_Layout_NHWC => (1, ndims-1)
    | NN_Layout_NCHWxc => (2, ndims-1)
    | _ => throw NNError(f"the shape layout {self.layout} is not supported in get_spatial_channel_range()")
    }
}

fun coerce_layouts(a: nnlayout_t, b: nnlayout_t) =
match (a, b) {
    | (NN_Layout_Unknown, _) => b
    | (_, NN_Layout_Unknown) => a
    | (NN_Layout_NC, _) => b
    | (_, NN_Layout_NC) => a
    | (_, _) =>
        if a != b {
            throw NNError(f"two layouts, {a} and {b}, cannot be used together")
        }
        a
}

// see https://github.com/onnx/onnx/blob/main/docs/Broadcasting.md
// for the description of multi-way broadcasting
fun nnshape_t.broadcast(another: nnshape_t)
{
    val layout = coerce_layouts(self.layout, another.layout)
    if self.shape == another.shape {
        self.{layout = layout}
    } else {
        val ndims0 = self.shape.size()
        val ndims1 = another.shape.size()
        val ndims = max(ndims0, ndims1)
        val d0 = ndims - ndims0
        val d1 = ndims - ndims1
        val sh = [for i <- 0:ndims {
            val a = if i >= d0 {self.shape[i-d0]} else {1}
            val b = if i >= d1 {another.shape[i-d1]} else {1}
            if a == b {a} else if a == 1 {b} else if b == 1 {a}
            else {
                throw NNError("the two shapes are not compatible for the mutual broadcasting")
            }
        }]
        nnshape_t {shape=sh, layout=layout}
    }
}

fun make_tensor(shape: nnshape_t, typ: nntyp_t)
{
    val total = shape.total()
    val data = match typ {
        | NN_I8 => NN_Data_I8(array(total, 0i8))
        | NN_U8 => NN_Data_U8(array(total, 0u8))
        | NN_I16 => NN_Data_I16(array(total, 0i16))
        | NN_U16 => NN_Data_U16(array(total, 0u16))
        | NN_I32 => NN_Data_I32(array(total, 0i32))
        | NN_U32 => NN_Data_U32(array(total, 0u32))
        | NN_I64 => NN_Data_I64(array(total, 0i64))
        | NN_U64 => NN_Data_U64(array(total, 0u64))
        | NN_FP32 => NN_Data_FP32(array(total, 0.f))
        | NN_FP64 => NN_Data_FP64(array(total, 0.))
        | NN_Bool => NN_Data_Bool(array(total, false))
        | _ => throw NNError(f"unsupported tensor type {typ}")
    }
    nntensor_t {shape=shape, data=data}
}

fun elemtype(x:int8) = NN_I8
fun elemtype(x:uint8) = NN_U8
fun elemtype(x:int16) = NN_I16
fun elemtype(x:uint16) = NN_U16
fun elemtype(x:int32) = NN_I32
fun elemtype(x:uint32) = NN_U32
fun elemtype(x:int64) = NN_I64
fun elemtype(x:uint64) = NN_U64
fun elemtype(x:float) = NN_FP32
fun elemtype(x:double) = NN_FP64
fun elemtype(x:bool) = NN_Bool

@private fun make_tensor_(arr: uint8 [,,,], typ: nntyp_t)
{
    fun make_data_(arr: uint8 [], typ: nntyp_t): nndata_t
    @ccode {
        fx_result->tag = typ->tag;
        fx_copy_arr(arr, &fx_result->u.NN_Data_U8);
        return FX_OK;
    }
    val shape = arr.size()
    val shape = [ shape.0, shape.1, shape.2, shape.3 ]
    val layout = NN_Layout_NCHW
    val data = make_data_(arr[:], typ)
    nntensor_t {shape=nnshape_t {shape=shape, layout=layout}, data=data}
}

fun make_tensor(arr: 't [,,,])
{
    val typ = elemtype(arr[0,0,0,0])
    make_tensor_(reinterpret(arr) : uint8 [,,,], typ)
}

fun nntensor_t.copy() =
    nntensor_t { shape=self.shape.copy(), data=self.data.copy() }
fun nntensor_t.isscalar() = self.shape.total() == 1
fun nntensor_t.isfloatscalar() =
    self.shape.total() == 1 &&
    (match self.data {NN_Data_FP32 _ => true | _ => false})

fun nnarg_t.isconst() = self.argkind == NN_Arg_Const

fun nnarg_t.copy() = nnarg_t {
    name = self.name,
    argkind = self.argkind,
    shape = self.shape.copy(),
    typ = self.typ
}

fun nnet_t.get_tensor(argidx: int) = self.tensors[argidx]

fun nnet_t.isconst(argidx: int) = self.args[argidx].argkind == NN_Arg_Const
fun nnet_t.istemp(argidx: int) = self.args[argidx].argkind == NN_Arg_Temp
fun nnet_t.isscalar(argidx: int) = self.tensors[argidx].isscalar()
fun nnet_t.isfloatscalar(argidx: int) = self.tensors[argidx].isfloatscalar()
fun nnet_t.get_input_names(): string [] =
    [for i <- self.graph.inpargs {
        self.args[i].name
    }]
fun nnet_t.get_output_names(): string [] =
    [for i <- self.graph.outargs {
        self.args[i].name
    }]

fun fit(shape: nnshape_t, typ: nntyp_t, data: nndata_t, buf: nnbuf_t): (nndata_t, nnbuf_t)
{
    val bufpadding = 128
    val new_total = shape.total()
    val elemsz = elemsize(typ)
    val typ0 = data.elemtype()
    val total0 = data.total()
    val reallocate = typ != typ0 || total0 != new_total

    fun fit_(total: int, elemsz: int, typ: nntyp_t,
        bufpadding: int, buf: nnbuf_t): (nndata_t, nnbuf_t)
    @ccode {
        int_ total_ = total*elemsz + bufpadding;
        fx_arr_t* data_arr = &fx_result->t0.u.NN_Data_U8;

        // if buffer has enough space to fit the new data, we re-use it
        if (total_ > buf->dim[0].size*(int_)buf->dim[0].step) {
            int fx_status = fx_make_arr(1, &total_, 1, 0, 0, 0, &fx_result->t1);
            if (fx_status < 0) return fx_status;
        } else {
            // copy the header
            fx_copy_arr(buf, &fx_result->t1);
        }

        // copy the header: data and buf will share data pointer and refcounter,
        // but will have different element type and number of elements.
        fx_copy_arr(&fx_result->t1, data_arr);
        data_arr->dim[0].size = total;
        data_arr->dim[0].step = (size_t)elemsz;
        fx_result->t0.tag = typ->tag;
        return FX_OK;
    }

    if reallocate || buf.size() < new_total*elemsz + bufpadding {
        fit_(new_total, elemsz, typ, bufpadding, buf)
    } else {
        (data, buf)
    }
}

fun nnet_t.copy_tensor_data(t_inp: int, t_out: int)
{
    fun copy_(inp: nndata_t, out: nndata_t): void
    @ccode {
        fx_arr_t* inp_arr, *out_arr;
        if (inp->tag != out->tag)
            return FX_SET_EXN_FAST(FX_EXN_TypeMismatchError);
        if (inp->tag == 1)
            return FX_OK;
        inp_arr = &inp->u.NN_Data_U8;
        out_arr = &out->u.NN_Data_U8;
        if (inp_arr->ndims != out_arr->ndims || inp_arr->ndims != 1 || inp_arr->dim[0].size != out_arr->dim[0].size)
            return FX_SET_EXN_FAST(FX_EXN_SizeMismatchError);
        if (inp_arr->data != out_arr->data)
            memcpy(out_arr->data, inp_arr->data, inp_arr->dim[0].size*inp_arr->dim[0].step);
        return FX_OK;
    }

    val inp = self.get_tensor(t_inp)
    val out = self.get_tensor(t_out)
    copy_(inp.data, out.data)
}

fun nnet_t.use_counts(): int []
{
    val nargs = self.args.size()
    val usecounts = array(nargs, 0)

    fun update_counts(graph: nngraph_t)
    {
        for op <- graph.prog {
            val (inps, _) = op.get_inputs_outputs()
            for i <- inps {usecounts[i] += 1}
            match op {
            | NN_If {then_branch, else_branch} =>
                update_counts(then_branch)
                update_counts(else_branch)
            | NN_Loop {body} =>
                update_counts(body)
            | _ => {}
            }
        }
    }

    update_counts(self.graph)
    usecounts
}

fun normalize_axis(axis: int, ndims: int) {
    val axis = if axis < 0 {axis + ndims} else {axis}
    assert(`0 <= axis <= ndims`)
    axis
}

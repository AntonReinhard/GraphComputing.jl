
function GraphComputing.cuda_kernel(
    graph::DAG, instance, machine::Machine, context_module::Module
)
    tape = GraphComputing.gen_tape(graph, instance, machine, context_module)

    init_caches = Expr(:block, tape.initCachesCode...)
    assign_inputs = Expr(:block, GraphComputing.expr_from_fc.(tape.inputAssignCode)...)
    code = Expr(:block, GraphComputing.expr_from_fc.(tape.computeCode)...)

    function_id = GraphComputing.to_var_name(UUIDs.uuid1(rng[1]))
    res_sym = eval(
        GraphComputing.gen_access_expr(
            GraphComputing.entry_device(tape.machine), tape.outputSymbol
        ),
    )
    expr = Meta.parse(
        "function compute_$(function_id)(input_vector, output_vector, n::Int64)
            id = (blockIdx().x - 1) * blockDim().x + threadIdx().x
            if (id > n)  
                return
            end
            @inline data_input = input_vector[id]
            $(init_caches)
            $(assign_inputs)
            $code
            @inline output_vector[id] = $res_sym
            return nothing
        end"
    )

    return RuntimeGeneratedFunction(@__MODULE__, context_module, expr)
end

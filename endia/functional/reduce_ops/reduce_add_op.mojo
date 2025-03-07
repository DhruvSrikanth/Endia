from endia import Array
from endia.utils import (
    array_shape_to_list,
    compute_stride,
    setup_array_shape,
    list_to_array_shape,
)
from endia.utils.aliases import dtype, nelts, NA
from algorithm import vectorize, parallelize
import math
from endia.functional._utils import contiguous

from endia.functional._utils import (
    op_array,
    setup_shape_and_data,
)
from ._utils import DifferentiableReduceOp
from endia.functional import expand
from endia.functional import squeeze

####-----------------------------------------------------------------------------------------------------------------####
#### Reduce Ops
####-----------------------------------------------------------------------------------------------------------------####


struct ReduceAdd(DifferentiableReduceOp):
    @staticmethod
    fn compute_shape(inout curr: ArrayShape, args: List[ArrayShape]) raises:
        """
        Computes the shape of an array after reducing along a specific axis.

        Args:
            curr: The ArrayShape to store the result of the computation.
            args: The ArrayShape to reduce, and the axis to reduce along encoded in an ArrayShape.

        #### Constraints:
        - The axis must be a valid axis of the ArrayShape (args[0]).
        - The number of axis must not exceed the number of dimensions of the ArrayShape (args[0]).
        """
        var arg = args[0]
        var axis = array_shape_to_list(args[1])
        var shape = arg.shape_node[].shape
        var new_shape = List[Int]()
        for i in range(len(shape)):
            if not list_contains(axis, i):
                new_shape.append(shape[i])
            else:
                new_shape.append(1)
        curr.setup(new_shape)

    @staticmethod
    fn __call__(inout curr: Array, args: List[Array]) raises:
        """
        Performs the forward pass for element-wise addition of two arrays.

        Computes the sum of the input arrays and stores the result in the current array.
        Initializes the current array if not already set up.

        Args:
            curr: The current array to store the result (modified in-place).
            args: A list containing the input arrays.

        #### Note:
        This function assumes that the shape and data of the args are already set up.
        If the current array (curr) is not initialized, it computes the shape based on the input array and the axis and sets up the data accordingly.
        """
        setup_shape_and_data(curr)
        var arg = contiguous(args[0])
        var arg_shape = arg.shape()
        var arg_stride = arg.stride()
        var target_shape = curr.shape()
        var rank = curr.ndim()
        var target_stride = compute_stride(target_shape)
        for i in range(rank):
            if target_shape[i] == 1 and arg_shape[i] != 1:
                target_stride[i] = 0

        var target_storage_offset = curr.storage_offset()
        var curr_data = curr.data()
        var arg_data = arg.data()

        if rank != 1:
            # check if both shapes are actually equal and we simply have to perdorm a fast copy
            var rows = arg_shape[rank - 2]
            var cols = arg_shape[rank - 1]

            for i in range(0, arg.size(), rows * cols):
                var nd_idx = compute_nd_index(i, arg_shape)
                var target_idx_0 = compute_storage_offset(
                    nd_idx, target_stride, target_storage_offset
                )
                for j in range(rows):
                    var base_idx_1 = i + j * arg_stride[rank - 2]
                    var target_idx_1 = target_idx_0 + j * target_stride[
                        rank - 2
                    ]

                    if (
                        arg_stride[rank - 1] == 1
                        and target_stride[rank - 1] == 1
                    ):

                        @parameter
                        fn reduce_v[width: Int](k: Int):
                            var base_idx = base_idx_1 + k * arg_stride[rank - 1]
                            var target_idx = target_idx_1 + k * target_stride[
                                rank - 1
                            ]
                            curr_data.store[width=width](
                                target_idx,
                                curr_data.load[width=width](target_idx)
                                + arg_data.load[width=width](base_idx),
                            )

                        vectorize[reduce_v, nelts[dtype]()](cols)

                    else:
                        for k in range(cols):
                            var base_idx = base_idx_1 + k * arg_stride[rank - 1]
                            var target_idx = target_idx_1 + k * target_stride[
                                rank - 1
                            ]
                            curr_data.store(
                                target_idx,
                                curr_data.load(target_idx)
                                + arg_data.load(base_idx),
                            )
        else:
            # if the rank is one and we still want to reduce along the single axis
            if target_stride[0] == 0:
                var end = arg.size() - arg.size() % nelts[dtype]()
                for i in range(0, end, nelts[dtype]()):
                    curr_data.store(
                        0,
                        curr_data.load(0)
                        + arg_data.load[width = nelts[dtype]()](i).reduce_add(),
                    )
                for i in range(end, arg.size()):
                    curr_data.store(0, curr_data.load(0) + arg_data.load(i))
            # other wise, if we we have rank one but not´reduction, we simply copy the values
            else:
                var end = arg.size() - arg.size() % nelts[dtype]()
                for i in range(0, end, nelts[dtype]()):
                    curr_data.store[width = nelts[dtype]()](
                        i,
                        arg_data.load[width = nelts[dtype]()](i).reduce_add(),
                    )
                for i in range(end, arg.size()):
                    curr_data.store(i, arg_data.load(i))

        _ = arg

    @staticmethod
    fn jvp(primals: List[Array], tangents: List[Array]) raises -> Array:
        return default_jvp(primals, tangents)

    @staticmethod
    fn vjp(primals: List[Array], grad: Array, out: Array) raises -> List[Array]:
        """
        Computes the vector-Jacobian product for the addition function.

        Implements reverse-mode automatic differentiation for the addition function.

        Args:
            primals: A list containing the primal input arrays.
            grad: The gradient of the output with respect to some scalar function.
            out: The output of the forward pass (unused in this function).

        Returns:
            A list containing the gradient with respect to the input.

        #### Note:
        The vector-Jacobian product for the addition is computed as the gradient itself.
        """
        return List(expand(grad, primals[0].array_shape()))

    @staticmethod
    fn fwd(arg0: Array, axis: List[Int]) raises -> Array:
        """
        Reduces the input array along the specified axis by summing the elements.

        Args:
            arg0: The input array.
            axis: The axis along which to reduce the array.

        Returns:
            An array containing the sum of the input array along the specified axis.

        #### Examples:
        ```python
        a = Array([[1, 2], [3, 4]])
        result = reduce_add(a, List(0))
        print(result)
        ```

        #### Note:
        This function supports:
        - Automatic differentiation (forward and reverse modes).
        - Complex valued arguments.
        """
        var arr_shape = setup_array_shape(
            List(arg0.array_shape(), list_to_array_shape(axis)),
            "reduce_add",
            ReduceAdd.compute_shape,
        )

        return op_array(
            arr_shape,
            List(arg0),
            NA,
            "reduce_add",
            ReduceAdd.__call__,
            ReduceAdd.jvp,
            ReduceAdd.vjp,
        )


fn reduce_add(arg0: Array, axis: List[Int]) raises -> Array:
    """
    Reduces the input array along the specified axis by summing the elements.

    Args:
        arg0: The input array.
        axis: The axis along which to reduce the array.

    Returns:
        An array containing the sum of the input array along the specified axis.

    #### Examples:
    ```python
    a = Array([[1, 2], [3, 4]])
    result = reduce_add(a, List(0))
    print(result)
    ```

    #### Note:
    This function supports:
    - Automatic differentiation (forward and reverse modes).
    - Complex valued arguments.
    """
    return ReduceAdd.fwd(arg0, axis)

from endia import Array
from endia.utils.aliases import dtype, nelts, NA
import math
from endia.functional._utils import (
    setup_shape_and_data,
)
from ._utils import DifferentiableUnaryOp, unary_op_array, execute_unary_op

####-----------------------------------------------------------------------------------------------------------------####
#### Square Root
####-----------------------------------------------------------------------------------------------------------------####


struct Sqrt(DifferentiableUnaryOp):
    @staticmethod
    fn fwd(arg0: Array) raises -> Array:
        """Computes the square root of the input array element-wise.

        Args:
            arg0: The input array.

        Returns:
            An array containing the square root of each element in the input array.

        #### Examples:
        ```python
        a = Array([[1, 2], [3, 4]])
        result = sqrt(a)
        print(result)
        ```

        #### Note:
        This function supports:
        - Automatic differentiation (forward and reverse modes).
        - Complex valued arguments.
        """
        return unary_op_array(
            arg0, "sqrt", Sqrt.__call__, Sqrt.jvp, Sqrt.vjp, Sqrt.unary_simd_op
        )

    @staticmethod
    fn jvp(primals: List[Array], tangents: List[Array]) raises -> Array:
        """Computes the Jacobian-vector product for the square root function.

        Implements forward-mode automatic differentiation for the square root function.

        Args:
            primals: A list containing the primal input array.
            tangents: A list containing the tangent vector.

        Returns:
            The Jacobian-vector product for the square root function.

        #### Note:
        The Jacobian-vector product for the square root is computed as dx / (2 * sqrt(x)),
        where x is the primal input and dx is the tangent vector.
        """
        return tangents[0] / (2 * sqrt(primals[0]))

    @staticmethod
    fn vjp(primals: List[Array], grad: Array, out: Array) raises -> List[Array]:
        """Computes the vector-Jacobian product for the square root function.

        Implements reverse-mode automatic differentiation for the square root function.

        Args:
            primals: A list containing the primal input array.
            grad: The gradient of the output with respect to some scalar function.
            out: The output of the forward pass (unused in this function).

        Returns:
            A list containing the gradient with respect to the input.

        #### Note:
        The vector-Jacobian product for the square root is computed as grad / (2 * sqrt(x)),
        where x is the primal input and grad is the incoming gradient.
        """
        return grad / (2 * sqrt(primals[0]))

    @staticmethod
    fn unary_simd_op(
        arg0_real: SIMD[dtype, nelts[dtype]() * 2 // 2],
        arg0_imag: SIMD[dtype, nelts[dtype]() * 2 // 2],
    ) -> Tuple[
        SIMD[dtype, nelts[dtype]() * 2 // 2],
        SIMD[dtype, nelts[dtype]() * 2 // 2],
    ]:
        """
        Low-level function to compute the square root of a complex number represented as SIMD vectors.

        Args:
            arg0_real: The real part of the complex number.
            arg0_imag: The imaginary part of the complex number.

        Returns:
            The real and imaginary parts of the square root of the complex number as a tuple.
        """
        var r = math.sqrt(arg0_real * arg0_real + arg0_imag * arg0_imag)
        var real = math.sqrt((r + arg0_real) / 2)
        var imag = math.copysign(math.sqrt((r - arg0_real) / 2), arg0_imag)
        return real, imag

    @staticmethod
    fn __call__(inout curr: Array, args: List[Array]) raises:
        """Performs the forward pass for element-wise square root computation of an array.

        Computes the square root of each element in the input array and stores the result in the current array.
        Initializes the current array if not already set up.

        Args:
            curr: The current array to store the result (modified in-place).
            args: A list containing the input array.

        #### Note:
        This function assumes that the shape and data of the args are already set up.
        If the current array (curr) is not initialized, it computes the shape based on the input array and sets up the data accordingly.
        """
        setup_shape_and_data(curr)
        execute_unary_op(curr, args)


fn sqrt(arg0: Array) raises -> Array:
    """Computes the square root of the input array element-wise.

    Args:
        arg0: The input array.

    Returns:
        An array containing the square root of each element in the input array.

    #### Examples:
    ```python
    a = Array([[1, 2], [3, 4]])
    result = sqrt(a)
    print(result)
    ```

    #### Note:
    This function supports:
    - Automatic differentiation (forward and reverse modes).
    - Complex valued arguments.
    """
    return Sqrt.fwd(arg0)

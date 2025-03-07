import endia as nd


fn foo(x: List[nd.Array]) raises -> nd.Array:
    return nd.sum((x[0] * x[0] + x[1] * x[1]))


def example2():
    print("\n\nExample 2 ###########################################")

    print("\nImperative grad computation:")

    x = nd.Array("[[1.0,2.0,3.0],[1.0,2.0,3.0]]", requires_grad=True)
    y = nd.Array("[[1.0,2.0,3.0],[1.0,2.0,3.0]]", requires_grad=True)

    grads = nd.grad(outs=foo(List(x, y)), inputs=List(x, y), retain_graph=True)[
        List[nd.Array]
    ]
    x_grad = grads[0]
    y_grad = grads[1]
    print("grads:")
    print(str(x_grad))
    print(str(y_grad))

    x_hessians = nd.grad(outs=x_grad, inputs=List(x, y))[List[nd.Array]]
    y_hessians = nd.grad(outs=y_grad, inputs=List(x, y))[List[nd.Array]]
    print("hessians:")
    print(str(x_hessians[0]))
    print(str(x_hessians[1]))
    print(str(y_hessians[0]))
    print(str(y_hessians[1]))

    print("\nFunctional grad computation:")

    x = nd.Array("[[1.0,2.0,3.0],[1.0,2.0,3.0]]")
    y = nd.Array("[[1.0,2.0,3.0],[1.0,2.0,3.0]]")

    foo_grads = nd.grad(foo, argnums=List(0, 1))
    grads = foo_grads(List(x, y))[List[nd.Array]]
    x_grad = grads[0]
    y_grad = grads[1]
    print("grads:")
    print(str(x_grad))
    print(str(y_grad))

    foo_hessians = nd.grad(foo_grads, argnums=List(0, 1))
    hessians = foo_hessians(List(x, y))[List[nd.Array]]
    print("hessians:")
    print(str(hessians[0]))
    print(str(hessians[1]))
    print(str(hessians[2]))
    print(str(hessians[3]))

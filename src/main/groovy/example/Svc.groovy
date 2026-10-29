package example

import groovy.transform.CompileStatic

@CompileStatic
class Svc {
    static Object use(int i, Ctx ctx) {
        ctx
    }

    Object make(String name) {
        println Util.label()
        use(
                1,
                new Ctx(name: name)
        )
    }
}

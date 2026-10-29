# A named-argument constructor call loses a line number when the class is already compiled

Reported as [GROOVY-12551](https://issues.apache.org/jira/browse/GROOVY-12551). The fix is proposed in [apache/groovy#3080](https://github.com/apache/groovy/pull/3080), with a backport to `GROOVY_5_1_X` in commit [65e1f69728](https://github.com/jdaugherty/groovy/commit/65e1f69728b6a6e334071ca6273a6102b4b7d144).

With static compilation, Groovy 5 expands a constructor call with named arguments, `new Ctx(name: name)`, into a
constructor call followed by one assignment per argument. The assignment gets a line number entry only when `Ctx` is
compiled together with the caller. When `Ctx` is already compiled, the entry is missing, so the same source compiles
to a different class file, and a debugger cannot stop on that line.

Reproduced with Groovy 5.1.3. Groovy 4.0.33 writes the entry in both cases.

## The difference

```groovy
class Ctx {
    String name
}

@CompileStatic
class Svc {
    static Object use(int i, Ctx ctx) { ctx }

    Object make(String name) {
        println Util.label()                 // line 12
        use(                                 // line 13
                1,
                new Ctx(name: name)          // line 15
        )
    }
}
```

`groovyc-repro.sh` compiles all classes together, and again compiles `Svc` against the other classes compiled:

```
== line number table of Svc.make, compiled together:
  line 12: 0
  line 13: 7
  line 15: 16
== line number table of Svc.make, compiled against the other classes:
  line 12: 0
  line 13: 7
```

## In an incremental build

`demo.sh` runs the same thing through Gradle 9.8.0 with incremental Groovy compilation:

1. a full build, where all classes are compiled together;
2. a change to a method body in `Util`, which `Svc` uses only inside a method body;
3. an incremental build, where Gradle recompiles `Util` and `Svc` against the other classes, already compiled.

With Groovy 5.1.3 the class file of `Svc` changes although `Svc.groovy` did not:

```
Incremental compilation of 2 classes completed in 0.822 secs.

== 4. line number table of Svc.make, full build:
  line 12: 0
  line 13: 7
  line 15: 16
== line number table of Svc.make, incremental build:
  line 12: 0
  line 13: 7
```

## Cause

`ConstructorCallTransformer` builds `tmp.name = name` for each named argument, transforms it, and only then sets the
source position of the map entry on the result. When `Ctx` is compiled, static type checking knows its setter, so
`BinaryExpressionTransformer` rewrites the assignment into a setter call built from the untransformed expression,
which has no position yet, and nothing writes a line number. When `Ctx` is in the compilation unit, the assignment
stays a binary expression, which writes the line of the position set afterwards.

## Fix

Write the line of the map entry before generating the code for its assignment, whatever expression the transformer
returns. Both builds then write `line 15: 16`, as Groovy 4.0.33 did.

## Running it

```
./groovyc-repro.sh    # groovyc alone; needs groovyc on the PATH, or GROOVYC set to a groovyc command
./demo.sh             # Gradle 9.8.0: full build, a method body change in Util, incremental build, then both results
```

Both scripts leave the sources as they found them. The Groovy version is set in `gradle.properties`. To try a fix,
publish a Groovy build with it to the local Maven repository and pass its version, for example
`./demo.sh -PgroovyVersion=5.1.4-SNAPSHOT`.

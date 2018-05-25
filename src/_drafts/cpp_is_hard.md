## C++ is hard

I assumed I'd be okay. I had some grounding in C, and hoped also that my experiences in higher-level languages would count for something.

Reality hit, though.

### It's not like C

Pointer arithmetic mostly disappears, since containers know the length of strings and vectors, and since iterators hide some details.

Moreover, C++ replaces a lot of pointer use-cases with _references_ — which have a more constrained semantic.

C++ is object-oriented. No more need for malloc; declare some class members, and the constructor will allocate memory for you.

C++'s complexity partially [stems from](https://youtu.be/RT46MpK39rQ?t=29m51s) its goal of maintaining compatibility with C.

### It's not like Java

C++ has no formal "interface". But you get a similar effect using multiple inheritance and dynamic binding. Caveats: interface-like classes need a virtual destructor, and derived classes must re-declare any methods they intend to override.

### It's your memory now

In C++, you are responsible for ownership of memory. You need to think about who will destroy an object when it's no longer needed.

There's a maxim to help you keep on top of this: SBRM ([Scope-Bound Resource Management](https://stackoverflow.com/questions/2321511/what-is-meant-by-resource-acquisition-is-initialization-raii)). Rely on the fact that C++ will invoke the destructor of any object which goes out-of-scope. Ensure that your classes release all their resources during destruction, and at no other time.

If you wish to transfer memory out of the scope in which it was created — for example, returning a heap-allocated object from a factory method — you need a plan to ensure that said object gets destroyed when it leaves its _new_ scope. One approach here is to use the standard library's [smart pointers](https://stackoverflow.com/questions/395123/raii-and-smart-pointers-in-c).

Passing objects around requires some awareness, since you risk accidentally incurring unnecessary copy operations. In [special cases](https://en.wikipedia.org/wiki/Copy_elision#Return_value_optimization), the compiler may save you a copy.

### It's a big language

In languages like Java 7 or ES5, I feel reasonably comfortable saying, "I've used most of the language's features". I would also believe a fellow professional if they told me the same. But C++ is _vast_.

C++ has many features, and you may not use everything. For example, [proxy classes](https://stackoverflow.com/questions/994488/what-is-proxy-class-in-c#994925) and [expression templates](https://en.wikipedia.org/wiki/Expression_templates) may be more interesting to library developers, as they hide complexity from callers. [Variants](https://bitbashing.io/std-visit.html) are interesting if you're building an unmarshaller. [SFINAE](http://en.cppreference.com/w/cpp/language/sfinae) is interesting if you're [building a marshaller](https://jguegant.github.io/blogs/tech/sfinae-introduction.html) or a language runtime.

I was exposed to ideas I hadn't thought of before. Like overloading on _the run-time value_ of arguments ([SFINAE](http://en.cppreference.com/w/cpp/language/sfinae), Substitution Failure Is Not An Error):

```cpp
template <int I> void div(char(*)[I % 2 == 0] = 0) {
    // this overload is selected when I is even
}
template <int I> void div(char(*)[I % 2 == 1] = 0) {
    // this overload is selected when I is odd
}
```

The most arcane thing I've seen so far involves variadic templates, variadic `using` declarations (C++17), and user-defined template deduction (C++17, Clang 5):

```cpp
template<class... Ts> struct overloaded : Ts... { using Ts::operator()...; };
template<class... Ts> overloaded(Ts...) -> overloaded<Ts...>;
```

It creates a class whose constructor accepts a list of [_function objects_](https://stackoverflow.com/questions/356950/c-functors-and-their-uses), and copies each of their declared `operator()` overloads. Useful for [making visitors](https://bitbashing.io/std-visit.html) (C++17). Explained in detail [here](https://stackoverflow.com/questions/46604950/what-does-operator-mean-in-code-of-c).

### Lots of gotchas

Many things happen implicitly. Narrowing conversions, 

#### Wacky syntax



###
(Pat) I think my favorite part of bluespec is the method interface. It would be interesting to add something like that to magma.

(Priyanka) I agree, it helps group logically related ports together. You can also nest interfaces :)

---
(Pat) I was surprised about how much stuff was added to the module interface in the generated verilog code. We often talk about a hardware ABI, analogous to a software API (function calling convention). This allows languages to interoperate. This example makes me think we need a hw ABI if we are going to interoperate with different languages.

(Priyanka) Yes, bluespec has one set way of doing things, but we can think about other ways for magma. In bluespec, for each method you have 
* ready
* enable (if it changes state)
* input (if it takes input)
* output (if it produces output)

And in the module you have
* clock
* reset

It generates all of these by default. If you know that certain methods will always be ready, for example, if your method just reads a register, you can use (* always_ready *) on the interface definition and it will skip generating that signal, otherwise it will generate it and set it to 1. 

---
(Pat) In magma, you can subclass circuits. This is quite similar to the way you first created an interface and then implemented a module using that interface.

(Priyanka) Great! One big advantage of that is that you can create several implementations with the same interface; in a hierarchical design I can very easily swap out one implementation for another and the rest of the design remains unaffected. I end up doing a lot of this while designing.

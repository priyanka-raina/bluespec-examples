[`cb_simple/ConnectionBox.bsv`](cb_simple/ConnectionBox.bsv) is equivalent to the magma connection box with the following parameters:

* `width` is represented by arbitrary `type d` not necessarily a bit vector.
* `num_tracks` is represented by `numeric type n`.
* `feedthrough_outputs` is something that the connection box should not know, it should just be given the inputs it is supposed to multiplex, knowledge of feedthrough should be in a higher level module, so I have omited it. 

This module does not support `has_constant` and `default_value`. [`cb_with_optional_constant/ConnectionBox.bsv`](cb_with_optional_constant/ConnectionBox.bsv) supports this, but the code is much uglier with ifdefs.

Also, serialization of the configuration logic could be moved to the PE tile, if that is where the connection boxes are instantiated.

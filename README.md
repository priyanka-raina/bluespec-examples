['cb_simple/ConnectionBox.bsv'](cb_simple/ConnectionBox.bsv) is equivalent to the magma connection box with the following parameters:

* 'width' is represented by 'type d'.
* 'num_tracks' is represented by 'numeric type n'.
* 'feedthrough_outputs' is something that the connection box should not know, it should just be given the inputs it is supposed to multiplex, knowledge of feedthrough should be in a higher level module, so I have omited it.

This module does not support 'has_constant' and 'default_value'.

Also, serialization of the configuration logic is something that I would move to the PE tile, if that is where the connection boxes are instantiated.

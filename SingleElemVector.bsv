import Vector::*;

function a vecUnbind(Vector#(1,a) vec) = vec[0];

function Vector#(1,a) vecBind(a value) = cons(value, nil);

const xIn = 1000000000000;
const _x = 100000000000000000;
const _y = 100000000000000000;


console.log(100000000e18*100000000e18*100000000e18)


x0 = _x+xIn;
xy = k(_x,_y,0,0)
y = _y

console.log("x0",x0)
console.log("xy",xy)
console.log("y",y)

console.log("f0",f(x0,xy,y));
console.log("f1",f1(x0,xy,y));

const n = newt(x0,xy,y)
console.log("n", n)
console.log("_y", _y)
console.log("_y-n", (_y-n))
y = _y - n

console.log("y", y)

function k(x, y, a, b) {
    x = x+a;
    y = y-b;

    return (x*y)*(x*x+y*y)
}

function f1(x0, xy, y) {
    //3*(y-b)*(x+a)^2-3*y*x^2+(y-b)^3-y^3
    return 3*x0*(y*y)+(x0*x0*x0)
}

function f(x0, xy, y) {
    //(y-b)*(x+a)^3-y*x^3+(y-b)^3*(x+a)-y^3*x
    return x0*(y*y*y)+(x0*x0*x0)*y-xy;
}

// (x+a)^3*(y-b)+(y-b)^3*(x+a)=x^3*y+y^3*x

function newt(x0, xy, y) {
    for (i = 0; i < 255; i++) {
      y_prev = y;
      console.log("i: ",i," y: ",y)
      y = y - (f(x0,xy,y)/f1(x0,xy,y));
      if (y > y_prev) {
            if (y - y_prev <= 1) {
                return y
            }
      } else {
            if (y_prev - y <= 1) {
                return y
            }
      }
    }
    return y
}

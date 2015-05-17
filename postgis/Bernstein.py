# -*- coding: utf-8 -*-
"""
Created on Sat May 16 16:20:51 2015

@author: remi
"""
from math import pow

FactorialLookup = [
    1.0,
    1.0,
    2.0,
    6.0,
    24.0,
    120.0,
    720.0,
    5040.0,
    40320.0,
    362880.0,
    3628800.0,
    39916800.0,
    479001600.0,
    6227020800.0,
    87178291200.0,
    1307674368000.0,
    20922789888000.0,
    355687428096000.0,
    6402373705728000.0,
    121645100408832000.0,
    2432902008176640000.0,
    51090942171709440000.0,
    1124000727777607680000.0,
    25852016738884976640000.0,
    620448401733239439360000.0,
    15511210043330985984000000.0,
    403291461126605635584000000.0,
    10888869450418352160768000000.0,
    304888344611713860501504000000.0,
    8841761993739701954543616000000.0,
    265252859812191058636308480000000.0,
    8222838654177922817725562880000000.0,
    263130836933693530167218012160000000.0
]


def factorial(n):
    """
    just check if n is appropriate, then return the result

    :param n:
    :return: returns the value n! as a SUMORealing point number
    """
    # if (n < 0) { throw new Exception("n is less than 0"); }
    # if (n > 32) { throw new Exception("n is greater than 32"); }

    return FactorialLookup[n]


def Ni(n, i):
    """

    :param n:
    :param i:
    :return:
    """
    a1 = factorial(n)
    a2 = factorial(i)
    a3 = factorial(n - i)
    ni = a1/(a2 * a3)
    return ni


def Bernstein(n, i, t):
    """
    Calculate Bernstein basis

    :param n:
    :param i:
    :param t:
    :return:
    """
    ti = 1.0
    if not (t == 0.0 and i == 0):
        ti = pow(t, i)

    tni = 1.0
    if not (n == i and t == 1.0):
        tni = pow((1 - t), (n - i))

    # Bernstein basis
    basis = Ni(n, i) * ti * tni
    return basis


# url: http://people.sc.fsu.edu/~jburkardt/cpp_src/bernstein_polynomial/bernstein_polynomial.html
def bernstein_poly_01(n, x):
    """
    ****************************************************************************

      Purpose:

        BERNSTEIN_POLY_01 evaluates the Bernstein polynomials based in [0,1].

      Discussion:

        The Bernstein polynomials are assumed to be based on [0,1].

        The formula is:

          B(N,I)(X) = [N!/(I!*(N-I)!)] * (1-X)^(N-I) * X^I

      First values:

        B(0,0)(X) = 1

        B(1,0)(X) =      1-X
        B(1,1)(X) =                X

        B(2,0)(X) =     (1-X)^2
        B(2,1)(X) = 2 * (1-X)    * X
        B(2,2)(X) =                X^2

        B(3,0)(X) =     (1-X)^3
        B(3,1)(X) = 3 * (1-X)^2 * X
        B(3,2)(X) = 3 * (1-X)   * X^2
        B(3,3)(X) =               X^3

        B(4,0)(X) =     (1-X)^4
        B(4,1)(X) = 4 * (1-X)^3 * X
        B(4,2)(X) = 6 * (1-X)^2 * X^2
        B(4,3)(X) = 4 * (1-X)   * X^3
        B(4,4)(X) =               X^4

      Special values:

        B(N,I)(X) has a unique maximum value at X = I/N.

        B(N,I)(X) has an I-fold zero at 0 and and N-I fold zero at 1.

        B(N,I)(1/2) = C(N,K) / 2^N

        For a fixed X and N, the polynomials add up to 1:

          Sum ( 0 <= I <= N ) B(N,I)(X) = 1

      Licensing:

        This code is distributed under the GNU LGPL license.

      Modified:

        29 July 2011

      Author:

        John Burkardt

      Parameters:

        Input, int N, the degree of the Bernstein polynomials
        to be used.  For any N, there is a set of N+1 Bernstein polynomials,
        each of degree N, which form a basis for polynomials on [0,1].

        Input, double X, the evaluation point.

        Output, double BERNSTEIN_POLY[N+1], the values of the N+1
        Bernstein polynomials at X.
    """
    coefs_bernstein = [0.0]*(n+1)

    # if n == 0:
    # elif 0 < n:
    coefs_bernstein[0] = 1.0 - x
    coefs_bernstein[1] = x

    for i in range(2, n+1):
        coefs_bernstein[i] = x * coefs_bernstein[i-1]
        for j in range(i-1, 0, -1):
            coefs_bernstein[j] = x * coefs_bernstein[j-1] + (1.0 - x) * coefs_bernstein[j]
        coefs_bernstein[0] *= 1.0 - x
    return coefs_bernstein
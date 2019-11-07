# Ficus

This is a new functional language with first-class array support
and _planned_ object-oriented features. `ficus` compiler generates
a portable C/C++ code out of .fx files.

The code is distributed under Apache 2 license, see the [LICENSE](LICENSE)

The compiler has been written in OCaml and needs `ocaml`
(including `ocamlyacc` and `ocamllex` utilities),
`ocamlbuild` and `make` utility to build it.
In the near future it's planned to rewrite the compiler entirely in ficus.

The compiler was inspired by and uses a structure similar to min-caml
(http://esumii.github.io/min-caml/index-e.html) by Eijiro Sumii et al.
Here is the original license:

```
Copyright (c) 2005-2008, Eijiro Sumii, Moe Masuko, and Kenichi Asai
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions are
met:

 - Redistributions of source code must retain the above copyright
   notice, this list of conditions and the following disclaimer.

 - Redistributions in binary form must reproduce the above copyright
   notice, this list of conditions and the following disclaimer in the
   documentation and/or other materials provided with the
   distribution.

 - Neither the name of Information-Technology Promotion Agency, the
   name of University of Pennsylvania, the name of University of
   Tokyo, the name of Tohoku University, the name of Ochanomizu
   University, the name of Eijiro Sumii, the name of Moe Masuko, nor
   the name of Kenichi Asai may be used to endorse or promote products
   derived from this software without specific prior written
   permission.

THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS
"AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT
LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR
A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT
OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL,
SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
```

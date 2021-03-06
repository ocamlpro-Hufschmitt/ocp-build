(**************************************************************************)
(*                                                                        *)
(*                              OCamlPro TypeRex                          *)
(*                                                                        *)
(*   Copyright OCamlPro 2011-2016. All rights reserved.                   *)
(*   This file is distributed under the terms of the GPL v3.0             *)
(*      (GNU Public Licence version 3.0).                                 *)
(*                                                                        *)
(*     Contact: <typerex@ocamlpro.com> (http://www.ocamlpro.com/)         *)
(*                                                                        *)
(*  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,       *)
(*  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES       *)
(*  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND              *)
(*  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS   *)
(*  BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN    *)
(*  ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN     *)
(*  CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE      *)
(*  SOFTWARE.                                                             *)
(**************************************************************************)


module MinUnix = struct
  include MinUnix
  include OcpUnix
end

module Filename = struct
  include Filename
  include OcpFilename
end


(* write a little-endian int to a string *)
let write_le_int buf off i =
  buf.[off]   <- Char.unsafe_chr (i          land 0xff);
  buf.[off+1] <- Char.unsafe_chr ((i lsr 8)  land 0xff);
  buf.[off+2] <- Char.unsafe_chr ((i lsr 16) land 0xff);
  buf.[off+3] <- Char.unsafe_chr ((i lsr 24) land 0xff);
  if Sys.word_size = 64 then begin
    buf.[off+4] <- Char.unsafe_chr ((i lsr 32) land 0xff);
    buf.[off+5] <- Char.unsafe_chr ((i lsr 40) land 0xff);
    buf.[off+6] <- Char.unsafe_chr ((i lsr 48) land 0xff);
    buf.[off+7] <- Char.unsafe_chr ((i lsr 56) land 0xff);
  end

(* write 1 int *)
let output_le_int oc i =
  let buf = Bytes.create (Sys.word_size / 8) in
  write_le_int buf 0 i;
  output oc buf 0 (String.length buf)

(* write a list of ints *)
let output_le_ints oc il =
  let is = Sys.word_size / 8 in
  let buf = Bytes.create (is * List.length il) in
  OcpList.iteri (fun off i -> write_le_int buf (off * is) i) il;
  output oc buf 0 (String.length buf)

(* read a little-endian int from a string *)
let read_le_int buf off =
  let n = Char.code buf.[off]
    + ((Char.code buf.[off+1]) lsl 8)
    + ((Char.code buf.[off+2]) lsl 16)
    + ((Char.code buf.[off+3]) lsl 24) in
  if Sys.word_size = 64 then begin
    n
    + ((Char.code buf.[off+4]) lsl 32)
    + ((Char.code buf.[off+5]) lsl 40)
    + ((Char.code buf.[off+6]) lsl 48)
    + ((Char.code buf.[off+7]) lsl 56)
  end else
    n

(* read 1 int *)
let input_le_int ic =
  let buf = Bytes.create (Sys.word_size / 8) in
  really_input ic buf 0 (String.length buf);
  read_le_int buf 0


(* Read n ints *)
let input_le_ints ic n =
  let is = Sys.word_size / 8 in
  let buf = Bytes.create (n* is) in
  really_input ic buf 0 (String.length buf);
  let il = ref [] in
  for off = 0 to n-1 do
    il := read_le_int buf (off*is) :: !il
  done;
  List.rev !il

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


include Genlex

type t = {
  name   : string;
  lines  : string array;
  raw    : char Stream.t;
  tokens : token Stream.t;
  mutable last : string;
}

exception Parse_error of string * t

let sp = Printf.sprintf

let print_error t =
  let n, i = OcpString.indexes t.lines (Stream.count t.raw) in
  Printf.printf
    "File \"%s\", line %d, characters %d-%d:\n%!" t.name (n+1) (i - String.length t.last) i

let of_lines kws name ?(discard=fun _ -> false) lines =
  let raw = OcpStream.of_lines (List.filter (fun l -> not (discard l)) lines) in
  let lines = Array.of_list lines in
  let tokens = make_lexer kws raw in
  let last = "" in
  { name = name; lines = lines; raw = raw; tokens = tokens; last = last }

let string_of_token token =
  match token with
  | Ident id -> Printf.sprintf "%s" id
  | Kwd id   -> Printf.sprintf "%s" id
  | Int n    -> Printf.sprintf "%d" n
  | Char c   -> Printf.sprintf "%c" c
  | String s -> Printf.sprintf "\"%s\"" (String.escaped s)
  | Float n  -> Printf.sprintf "%f" n

let junk t =
  let token = string_of_token (Stream.next t.tokens) in
  t.last <- token

let string_of_token token =
  match token with
  | Ident id -> Printf.sprintf "Ident \"%s\"" id
  | Kwd id   -> Printf.sprintf "Kwd \"%s\"" id
  | Int n    -> Printf.sprintf "Int %d" n
  | Char c   -> Printf.sprintf "Char '%c'" c
  | String s -> Printf.sprintf "String \"%s\"" (String.escaped s)
  | Float n  -> Printf.sprintf "Float %f" n


(* The next token MAY be a string *)
let maybe_string s =
  match Stream.peek s.tokens with
  | Some (String str) -> junk s; Some str
  | _                 -> None

let parse_error msg s =
  raise (Parse_error (msg, s))

(* The next token MUST be a string *)
let string s =
  match maybe_string s with
  | Some s -> s
  | None   -> parse_error "string" s

(* The next token MUST be a keyword in [ks]. *)
(* [ks] associates keywords to their continuation. *)
let kwds s ks =
  match Stream.peek s.tokens with
  | Some (Kwd k) ->
    if List.mem_assoc k ks then begin
      junk s;
      (List.assoc k ks) s
    end else
      parse_error "kwds/1" s
  | _ -> parse_error "kwds/2:" s

(* The next token MUST be the keyword [k] *)
let kwd s k cont =
  match Stream.peek s.tokens with
  | Some (Kwd w) ->
    if k = w then begin
      junk s;
      cont s;
    end else
      parse_error (sp "kwd:%s/1" k) s
  | Some t -> parse_error (sp "kwd:%s:%s/2" k (string_of_token t)) s
  | None -> parse_error (sp "kwd:%s/3" k) s

let list s fn =
  let rec aux () =
    match
      try
        Some (fn s)
      with Parse_error _ -> None
    with
      None -> []
    | Some hd -> hd :: (aux ())
  in
  aux ()

let iter s fn =
  let rec aux () =
    try
      fn s;
      aux ()
    with Parse_error _ -> () in
  aux ()

let is_empty s =
  OcpStream.is_empty s.tokens || OcpStream.is_empty s.raw

let loop s fn =
  let rec aux () =
    iter s fn;
    try
      junk s;
      aux ()
    with Stream.Failure ->
      () in
  aux ()

let assert_empty s =
  try Stream.empty s.tokens
  with _ -> parse_error "empty" s

(* Discard blank lines and comments line starting by [c] *)
exception Found of bool
let is_comment c line =
  if String.length line = 0 then  (* it's a blank line *)
    true
  else
    try
      for i = 0 to String.length line - 1 do
        if line.[i] = c then (* it's a comment *)
          raise (Found true)
        else if not (OcpString.is_ws line.[i]) then
          raise (Found false)
      done;
      true (* it's a white-space line *)
    with Found t -> t

exception ParseError of int * string

let tokens_of_string lexer s =
  let str1 = Stream.of_string s in
  let str2 = lexer str1 in
  let list = ref [] in
  let error = try
                Stream.iter (fun token ->
                  list := token :: !list) str2;
                None
    with
      Stream.Error error ->
        Some (Stream.count str1, error)
  in
  List.rev !list, error

let tokens_of_string_exn lexer s =
  match tokens_of_string lexer s with
  | tokens, None -> tokens
  | _, Some (pos, error) -> raise (ParseError(pos,error))

let tokenlocs_of_string lexer s =
  let str1 = Stream.of_string s in
  let str2 = lexer str1 in
  let list = ref [] in
  try
    Stream.iter (fun token ->
      let token_pos = Stream.count str1 in
      list := (token, token_pos) :: !list) str2;
    List.rev !list
  with
    Stream.Error error ->
      raise (ParseError (Stream.count str1, error))

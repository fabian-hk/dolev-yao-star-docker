# Hands-on-Session DY* Documentation

## Different Types of Let Bindings

```ocaml
let*   (* Computation that depends on the global trace *)
let*?  (* Computation that depends on the global trace and can fail *)
let	   (* Computation that does not depend on the global trace and cannot fail *)
```

## State Handling

```ocaml
let* sid:sess_id = new_session_id alice in
set_state principal sess_id st;*
let*? st = get_state principal sess_id in
```

## URL

```ocaml
let u:url kv_types = {
   protocol:string;
   domain = {root_domain:principal; sub_domain = ""};
   port:int;
   path:string;
   query = [{ key:string; value:kv_types } <: key_value kv_types];
   fragment = {identifier = ""; data = []};
 } in
```

These are the possible values for the value in the query:
```ocaml
type kv_types: eqtype =
 | VS: s:string -> kv_types
 | VP: p:principal -> kv_types
 | VB: b:bytes -> kv_types
 | VID: i:id -> kv_types
 | VI: i:int -> kv_types
```

## Header

```ocaml
let headers:list header = [] in
```

These are the possible types for the item in the headers list:
```ocaml
type header (a:eqtype): eqtype =
 | Host: string -> nat -> header a
 | ContentType: string -> header a
 | CacheControl: string -> header a
 | Cookie: list (key_value a) -> header a
 | Authorization: auth_scheme -> header a
 | Accept: string -> header a
```

## Send Request
```ocaml
let http_req:http_request = mk_http_request method url (list header) empty_body in
let*? (msg_id, hmeta_data):(timestamp & http_meta_data) = send_https_request communication_keys_sess_ids principal (url kv_types) http_request in
```

These are the possible values for method:
```ocaml
type method =
  | GET
  | POST
```

## Receiving Request

```ocaml
let*? (http_req, hmeta_data):(http_request & http_meta_data) = receive_https_request communication_keys_sess_ids principal timestamp in
```

## Web Types

```ocaml
let body:web_types = JSON [] in
```

These are the possible values for web_types:
```ocaml
type web_types: eqtype =
  | URLEncoded: list web_kv -> web_types
  | JSON: list web_kv -> web_types

type web_kv: eqtype = {
  key:string;
  value:kv_types;
}
```

## Send Response

```ocaml
let http_res:http_response = mk_http_response nat (list header) web_types in
let*? msg_id_out:timestamp = send_https_response principal http_meta_data http_response in
```

## Receive Response

```ocaml
let*? (http_res, hmeta_data):(http_response & http_meta_data) = receive_https_response http_meta_data principal timestamp in
```

## Parse Data From Web Types

```ocaml
let*? value:string = return (get_string_from_json_encoded string web_types) in
let*? value:int = return (get_int_from_json_encoded string web_types) in
```

## Print a String on the Console

```ocaml
let _ = IO.debug_print_string (Printf.sprintf "value=%s\n" value) in
```

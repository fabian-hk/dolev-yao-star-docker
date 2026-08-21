# Hands-on-Session DY* Documentation

This document contains the most important DY* functions and code patterns used during the hands-on session. DY* protocols are modeled as event-driven state machines whose execution is recorded in a global symbolic trace containing all protocol events and exchanged messages. Functions returning `traceful SOME TYPE` interact with this symbolic execution state and therefore depend on the current global trace.

A more detailed documentation of DY* can be found [here](https://reprosec.org/dolev-yao-star-documentation/) (should not be necessary to look into it for this hands-on-session).

## Different Types of Let Bindings

```ocaml
let*   (* Computation that depends on the global trace, e.g. traceful SOME TYPE *)
let*?  (* Computation that depends on the global trace and may return None on failure, e.g. traceful (option SOME TYPE) *)
let	   (* Computation that does not depend on the global trace and cannot fail *)
```

## State Handling

The following state handling functions assume that the protocol uses the type `state_t` for the protocol.

```ocaml
val new_session_id: principal -> traceful sess_id
val set_state: principal -> sess_id -> state_t -> unit
val get_state: principal -> sess_id -> traceful (option state_t)
```

## URL

```ocaml
type url = {
   protocol:protocol_t;
   domain:domain_t;
   port:int;
   path:string;
   query:list (key_value ky_types);
   fragment = {identifier:string; data:list (key_value ky_types)};
 }
```

**key_value type:**
```ocaml
type key_value = {
  key:string;
  value:kv_types;
}
```

**ky_types type:**
```ocaml
type kv_types: eqtype =
 | VS: s:string -> kv_types
 | VP: p:principal -> kv_types
 | VB: b:bytes -> kv_types
 | VID: i:id_t -> kv_types
 | VI: i:int -> kv_types
```

**protocol_t type:**
```ocaml
type protocol_t =
  | HTTP
  | HTTPS
```

**domain_t type:**
```ocaml
type domain_t = list string
```

## Header

Example header:

```ocaml
let headers:list header = [
  Host ["example"; "com"] 443;
  ContentType "application/json"
] in
```

These are the possible types for the item in the headers list:
```ocaml
type header_t (a:eqtype): eqtype =
  | Host: domain:domain_t -> port:nat -> header_t a
  | UserAgent: user_agent_t -> header_t a
  | ContentType: string -> header_t a
  | CacheControl: string -> header_t a
  | Cookie: cookie_t -> header_t a
  | SetCookie: cookie_t -> header_t a
  | Authorization: auth_scheme_t -> header_t a
  | Accept: string -> header_t a
  | Location: url_t a -> header_t a
  | Referer: url_t a -> header_t a
```

## Send Request
```ocaml
val mk_http_request: method_t -> url_t -> (list header) -> web_types -> http_request_t (* Use empty_body as the web_types here *)
val send_https_request: communication_keys_sess_ids -> principal -> url_t -> http_request_t -> traceful (option (timestamp & http_meta_data))
```

Example send HTTPS request function call:

```ocaml
let*? (msg_id, hmeta_data) = send_https_request comm_keys_ids client url http_req in
```

These are the possible values for method:
```ocaml
type method_t =
  | HEAD
  | GET
  | POST
```

## Receiving Request

```ocaml
val receive_https_request: communication_keys_sess_ids -> principal -> timestamp -> traceful (option (http_request_t & http_meta_data))
```

Example receive HTTPS request function call:

```ocaml
let*? (http_req, hmeta_data) = receive_https_request comm_keys_ids server msg_id in
```

## Web Types

Example body:

```ocaml
let body:web_types = JSON [{key="username"; value=VS "Alice"}] in
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
val mk_http_response: nat (* Status code *) -> (list header) -> web_types (* Body *) -> http_response_t
val send_https_response: principal -> http_meta_data -> http_response_t -> traceful (option timestamp)
```

## Receive Response

```ocaml
val receive_https_response: http_meta_data -> principal -> timestamp -> traceful (option http_response_t)
```

## Extract Data From JSON Bodies

```ocaml
val get_string_from_json_encoded: string -> web_types -> option string
val get_int_from_json_encoded: string -> web_types -> option int in
```

Example extraction function call:

```ocaml
let*? username = return (get_string_from_json_encoded "username" http_res.body) in
```

## Print a String on the Console

Example string printing function:

```ocaml
let _ = IO.debug_print_string (Printf.sprintf "username=%s\n" username) in
```

The formatting options are the same as for the C `printf` function:

- `%s`: string
- `%d`: integer
- `\n`: new line
- ...

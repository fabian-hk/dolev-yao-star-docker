module DY.HandsOnSessionLogin.Invariants

open Comparse
open FStar.List.Tot { for_allP, for_allP_eq, memP }
open DY.Core
open DY.Lib

open DY.Lib.Web
open DY.Lib.Web.HTTP.Invariants
open DY.Lib.Web.Data.Default.Invariants

open DY.HandsOnSessionLogin.Protocol

#set-options "--fuel 0 --ifuel 0 --z3cliopt 'smt.qi.eager_threshold=100'"

(*** Crypto predicates ***)

instance crypto_usages_login: crypto_usages = default_crypto_usages

let pke_predicates_login: list (string & pke_crypto_predicate) = [
  pke_crypto_predicate_and_tag_communication_layer_reqres (http_t web_types kv_types);
]

let sign_predicates_login: list (string & sign_crypto_predicate) = [
  sign_crypto_predicate_and_tag_communication_layer_reqres (http_t web_types kv_types);
]

let aead_predicates_login: list (string & aead_crypto_predicate) = [
  aead_crypto_predicate_and_tag_communication_layer_reqres (http_t web_types kv_types);
]

[@@ "opaque_to_smt"]
let crypto_predicates_login: crypto_predicates = {
  default_crypto_predicates with
  pke_pred = mk_pke_predicate pke_predicates_login;
  sign_pred = mk_sign_predicate sign_predicates_login;
  aead_pred = mk_aead_predicate aead_predicates_login;
}

instance crypto_invariants_login: crypto_invariants = {
  usages = crypto_usages_login;
  preds = crypto_predicates_login;
}

#push-options "--fuel 2 --ifuel 0"
let _ = (
  reveal_opaque (`%crypto_predicates_login) crypto_predicates_login;
  assert_norm(List.Tot.no_repeats_p (List.Tot.map fst (pke_predicates_login)));
  do_split_boilerplate mk_pke_predicate_correct pke_predicates_login
)
let _ = (
  reveal_opaque (`%crypto_predicates_login) crypto_predicates_login;
  assert_norm(List.Tot.no_repeats_p (List.Tot.map fst (sign_predicates_login)));
  do_split_boilerplate mk_sign_predicate_correct sign_predicates_login
)
let _ = (
  reveal_opaque (`%crypto_predicates_login) crypto_predicates_login;
  do_split_boilerplate mk_aead_predicate_correct aead_predicates_login
)
#pop-options

(*** HTTP predicates ***)

// Request predicates
val wt_send_request_pred_key_username: wt_send_request_pred_key "username"
let wt_send_request_pred_key_username = {
  pred = (fun tr client server key_label http_req -> (
    match get_principal_from_json_encoded "username" http_req.body with
    | Some username -> (
      username == client /\
      event_triggered tr client (ClientAuthenticatesToServer client server)
    )
    | None -> False
  ));
  pred_later = (fun tr1 tr2 client server key_label http_req -> ());
}

#push-options "--ifuel 1"
val wt_send_request_pred_key_password: wt_send_request_pred_key "password"
let wt_send_request_pred_key_password = {
  pred = (fun tr client server key_label http_req -> True);
  pred_later = (fun tr1 tr2 client server key_label http_req -> ());
}
#pop-options

let request_predicates_login: list (dtuple2 string wt_send_request_pred_key) = [
  (|"username", wt_send_request_pred_key_username|);
  (|"password", wt_send_request_pred_key_password|);
]

// Response predicates
#push-options "--ifuel 1"
val wt_send_response_pred_key_username: wt_send_response_pred_key "username"
let wt_send_response_pred_key_username = {
  pred = (fun tr server key_label http_req http_res -> (
    match get_string_from_json_encoded "username" http_res.body, get_set_cookie_header "accessToken" http_res.headers with
    | Some username, Some cookie -> (
      event_triggered tr server (ServerAuthenticatedClient username server cookie <: event_t)
    )
    | _ -> False
  ));
  pred_later = (fun tr1 tr2 server key_label http_req http_res -> ());
}
#pop-options

val wt_send_response_pred_key_true: key:string -> wt_send_response_pred_key key
let wt_send_response_pred_key_true key = {
  pred = (fun tr server key_label http_req http_res -> True);
  pred_later = (fun tr1 tr2 server key_label http_req http_res -> ());
}

let response_predicates_login: list (dtuple2 string wt_send_response_pred_key) = [
  (|"id", wt_send_response_pred_key_true "id"|);
  (|"username", wt_send_response_pred_key_username|);
  (|"email", wt_send_response_pred_key_true "email"|);
  (|"firstName", wt_send_response_pred_key_true "firstName"|);
  (|"lastName", wt_send_response_pred_key_true "lastName"|);
]

instance web_types_predicates_login: web_types_preds = {
  wt_send_request_pred = mk_wt_send_request_pred request_predicates_login;
  wt_send_response_pred = mk_wt_send_response_pred response_predicates_login;
}

instance http_query_predicates_login: http_query_preds web_types kv_types = {
  http_query_pred = (fun tr client server http_req key_label ->
    for_allP (is_knowable_by_key_value key_label tr) http_req.query
  );
  http_query_pred_later = (fun tr1 tr2 client server http_req key_label ->
    is_knowable_by_key_value_later tr1 tr2 key_label http_req.query
  );
}

instance http_header_predicates_login: http_header_preds web_types kv_types = {
  authorization_header_pred = (fun tr client server http_req key_label -> True);
  authorization_header_pred_later = (fun tr1 tr2 client server http_req key_label -> ());
  location_header_pred = (fun tr client server http_req http_res key_label -> True);
  location_header_pred_later = (fun tr1 tr2 client server http_req http_res key_label -> ());
}

instance browser_predicates_login: browser_preds web_types kv_types = {
  http_request_pred = (fun tr client server http_req key_label -> True);
  http_request_pred_later = (fun tr1 tr2 client server http_req key_label -> ());
}


(*** Event invariant ***)

// 1. Setup event predicate
#push-options "--ifuel 1"
let event_predicate_login: event_predicate event_t =
  fun tr prin e ->
    match e with
    | ClientAuthenticatesToServer client server -> True
    | ServerAuthenticatedClient client server cookie ->
      prin == server /\
      ((event_triggered tr client (ClientAuthenticatesToServer client server) /\
        is_secret (comm_label client server) tr cookie.value) \/
       is_corrupt tr (principal_label client) \/ is_corrupt tr (principal_label server))
    | ClientReceivedCookie client server cookie ->
      prin == client /\
      ((event_triggered tr server (ServerAuthenticatedClient client server cookie) /\
        is_secret (comm_label client server) tr cookie.value) \/
       is_corrupt tr (principal_label client) \/ is_corrupt tr (principal_label server))
#pop-options

(*** Protocol state invariant ***)

// 2. Setup state predicate
#push-options "--ifuel 1 --z3rlimit 80"
let state_predicate_login: local_state_predicate state_t = {
  pred = (fun tr prin sess_id st -> True);
  pred_later = (fun tr1 tr2 prin sess_id st -> ());
  pred_knowable = (fun tr prin sess_id st -> admit());
}
#pop-options

let state_update_predicate_login: local_state_update_predicate state_t =
  default_local_state_update_pred state_t

(*** Global protocol invariants ***)

let all_sessions_login: list (dtuple2 string local_bytes_state_predicate) = [
  state_predicate_and_tag_communication_layer_reqres (http_t web_types kv_types);
  pki_tag_and_invariant;
  private_keys_tag_and_invariant;
  mk_local_state_tag_and_pred state_predicate_login;
]

let all_session_updates_login: list (dtuple2 string local_bytes_state_update_predicate) = [
  state_update_predicates_communication_layer_and_tag (http_t web_types kv_types);
  pki_tag_and_state_update_pred;
  private_keys_tag_and_state_update_pred;
  mk_local_state_tag_and_update_pred state_update_predicate_login;
]

let all_events_login: list (string & compiled_event_predicate) =
  FStar.List.Tot.append
    (event_predicate_communication_layer_reqres_and_tag (http_t web_types kv_types))
    [mk_event_tag_and_pred event_predicate_login]

[@@ "opaque_to_smt"]
let trace_invariants_login: trace_invariants = {
  state_pred = mk_state_pred all_sessions_login;
  state_update_pred = mk_state_update_pred all_session_updates_login;
  event_pred = mk_event_pred all_events_login;
}

instance protocol_invariants_login: protocol_invariants = {
  crypto_invs = crypto_invariants_login;
  trace_invs = trace_invariants_login;
}

(*** Predicate inclusion boilerplate ***)

#push-options "--fuel 5"
let fst_dtuple (x: dtuple2 'a 'b) : 'a = Mkdtuple2?._1 x

let _ = (
  reveal_opaque (`%trace_invariants_login) trace_invariants_login;
  assert_norm(List.Tot.no_repeats_p (List.Tot.map fst_dtuple (all_sessions_login)));
  do_split_boilerplate mk_state_pred_correct all_sessions_login
)
let _ = (
  reveal_opaque (`%trace_invariants_login) trace_invariants_login;
  assert_norm(List.Tot.no_repeats_p (List.Tot.map fst_dtuple (all_session_updates_login)));
  do_split_boilerplate mk_state_update_pred_correct all_session_updates_login
)
let _ = (
  reveal_opaque (`%trace_invariants_login) trace_invariants_login;
  assert_norm(List.Tot.no_repeats_p (List.Tot.map fst (all_events_login)));
  do_split_boilerplate mk_event_pred_correct all_events_login
)

let _ = do_split_boilerplate mk_wt_send_request_pred_correct request_predicates_login
let _ = do_split_boilerplate mk_wt_send_response_pred_correct response_predicates_login

let _:squash (has_pki_invariant /\ has_pki_state_update_invariant) = reveal_opaque (`%trace_invariants_login) trace_invariants_login
let _:squash (has_private_keys_invariant /\ has_private_keys_state_update_invariant) = reveal_opaque (`%trace_invariants_login) trace_invariants_login
let _:squash (has_local_state_predicate state_predicate_login) = reveal_opaque (`%trace_invariants_login) trace_invariants_login
let _:squash (has_local_state_update_predicate state_update_predicate_login) = reveal_opaque (`%trace_invariants_login) trace_invariants_login
let _:squash (has_event_pred event_predicate_login) = reveal_opaque (`%trace_invariants_login) trace_invariants_login
let _:squash (has_communication_layer_reqres_predicates (http_t web_types kv_types)) = reveal_opaque (`%crypto_predicates_login) crypto_predicates_login; reveal_opaque (`%trace_invariants_login) trace_invariants_login

let _:squash (has_web_types_request_key_pred (|"username", wt_send_request_pred_key_username|)) = reveal_opaque (`%trace_invariants_login) trace_invariants_login
let _:squash (has_web_types_request_key_pred (|"password", wt_send_request_pred_key_password|)) = reveal_opaque (`%trace_invariants_login) trace_invariants_login
#pop-options

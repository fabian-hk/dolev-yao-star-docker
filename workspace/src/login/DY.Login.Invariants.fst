module DY.Login.Invariants

open Comparse
open FStar.List.Tot { for_allP, for_allP_eq, memP }
open DY.Core
open DY.Lib

open DY.Lib.Web
open DY.Lib.Web.HTTP.Invariants
open DY.Lib.Web.Data.Default.Invariants

open DY.Login.Protocol

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

(*** HTTP predicates ***)

val wt_send_request_pred_key_username: wt_send_request_pred_key "username"
let wt_send_request_pred_key_username = {
  pred = (fun tr client server key_label http_req -> (
    match get_principal_from_json_encoded "username" http_req.body with
    | Some username -> username == client
    | None -> False
  ));
  pred_later = (fun tr1 tr2 client server key_label http_req -> ());
}

#push-options "--ifuel 1"
val wt_send_request_pred_key_password: wt_send_request_pred_key "password"
let wt_send_request_pred_key_password = {
  pred = (fun tr client server key_label http_req ->
    match get_bytes_from_json_encoded "password" http_req.body with
    | Some password -> is_secret (comm_label client server) tr password
    | None -> False
  );
  pred_later = (fun tr1 tr2 client server key_label http_req -> ());
}
#pop-options

val wt_send_request_pred_key_true: key:string -> wt_send_response_pred_key key
let wt_send_request_pred_key_true key = {
  pred = (fun tr server key_label http_req http_res -> True);
  pred_later = (fun tr1 tr2 server key_label http_req http_res -> ());
}

let request_predicates_login: list (dtuple2 string wt_send_request_pred_key) = [
  (|"username", wt_send_request_pred_key_username|);
  (|"password", wt_send_request_pred_key_password|);
]

let response_predicates_login: list (dtuple2 string wt_send_response_pred_key) = [
  (|"id", wt_send_request_pred_key_true "id"|);
  (|"username", wt_send_request_pred_key_true "username"|);
  (|"email", wt_send_request_pred_key_true "email"|);
  (|"firstName", wt_send_request_pred_key_true "firstName"|);
  (|"lastName", wt_send_request_pred_key_true "lastName"|);
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

let event_predicate_login: event_predicate event_t =
  fun tr prin e ->
    match e with
    | ServerAuthenticatedUser client server request key ->
      prin == server /\
      event_triggered tr client (CommClientSendRequest Unauthenticated client server (Request request) key <: communication_reqres_event (http_t web_types kv_types))

(*** Protocol state invariant ***)

#push-options "--ifuel 1 --z3rlimit 50"
let state_predicate_login: local_state_predicate state_t = {
  pred = (fun tr prin sess_id st ->
    match st with
    | InitialState client server password ->
      (prin == client \/ prin == server) /\
      is_secret (comm_label client server) tr password
    | SendRequest hmeta_data ->
      comm_meta_data_knowable tr (http_t web_types kv_types) prin hmeta_data
  );
  pred_later = (fun tr1 tr2 prin sess_id st -> ());
  pred_knowable = (fun tr prin sess_id st ->
    match st with
    | InitialState client server password -> ()
    | SendRequest hmeta_data ->
      comm_meta_data_knowable_proof tr (http_t web_types kv_types) state_t sess_id st prin hmeta_data
  );
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
(*let _ = do_split_boilerplate mk_pke_predicate_correct pke_predicates_login
let _ = do_split_boilerplate mk_sign_predicate_correct sign_predicates_login
let _ = do_split_boilerplate mk_aead_predicate_correct aead_predicates_login*)
let _ = do_split_boilerplate mk_wt_send_request_pred_correct request_predicates_login
let _ = do_split_boilerplate mk_wt_send_response_pred_correct response_predicates_login

let _:squash (has_pki_invariant /\ has_pki_state_update_invariant) = reveal_opaque (`%trace_invariants_login) trace_invariants_login
let _:squash (has_private_keys_invariant /\ has_private_keys_state_update_invariant) = reveal_opaque (`%trace_invariants_login) trace_invariants_login
let _:squash (has_local_state_predicate state_predicate_login) = reveal_opaque (`%trace_invariants_login) trace_invariants_login
let _:squash (has_local_state_update_predicate state_update_predicate_login) = reveal_opaque (`%trace_invariants_login) trace_invariants_login
let _:squash (has_event_pred event_predicate_login) = reveal_opaque (`%trace_invariants_login) trace_invariants_login

let _:squash (has_web_types_request_key_pred (|"username", wt_send_request_pred_key_username|)) = reveal_opaque (`%trace_invariants_login) trace_invariants_login
let _:squash (has_web_types_request_key_pred (|"password", wt_send_request_pred_key_password|)) = reveal_opaque (`%trace_invariants_login) trace_invariants_login
#pop-options

(*)
val login_state_predicates_correct:
  squash (for_allP has_local_bytes_state_predicate all_sessions_login)
let login_state_predicates_correct =
  assert_norm (List.Tot.no_repeats_p (List.Tot.map dfst all_sessions_login));
  mk_state_pred_correct all_sessions_login

val login_state_update_predicates_correct:
  squash (for_allP has_local_bytes_state_update_predicate all_session_updates_login)
let login_state_update_predicates_correct =
  assert_norm (List.Tot.no_repeats_p (List.Tot.map dfst all_session_updates_login));
  mk_state_update_pred_correct all_session_updates_login

val login_event_predicates_correct:
  squash (for_allP has_compiled_event_pred all_events_login)
let login_event_predicates_correct =
  assert_norm (List.Tot.no_repeats_p (List.Tot.map fst all_events_login));
  mk_event_pred_correct all_events_login

val login_has_pke_predicate:
  squash (
    has_pke_predicate
      (pke_crypto_predicate_and_tag_communication_layer_reqres
        (http_t web_types kv_types))
  )
let login_has_pke_predicate = ()

val login_has_sign_predicate:
  squash (
    has_sign_predicate
      (sign_crypto_predicate_and_tag_communication_layer_reqres
        (http_t web_types kv_types))
  )
let login_has_sign_predicate = ()

val login_has_aead_predicate:
  squash (
    has_aead_predicate
      (aead_crypto_predicate_and_tag_communication_layer_reqres
        (http_t web_types kv_types))
  )
let login_has_aead_predicate = ()

#push-options "--ifuel 1 --z3rlimit 100"
val login_has_state_predicate:
  squash (has_local_state_predicate state_predicate_login)
let login_has_state_predicate =
  login_state_predicates_correct;
  for_allP_eq has_local_bytes_state_predicate all_sessions_login;
  assert_norm (
    memP (mk_local_state_tag_and_pred state_predicate_login) all_sessions_login
  );
  ()

val login_has_state_update_predicate:
  squash (has_local_state_update_predicate state_update_predicate_login)
let login_has_state_update_predicate =
  login_state_update_predicates_correct;
  for_allP_eq has_local_bytes_state_update_predicate all_session_updates_login;
  assert_norm (
    memP
      (mk_local_state_tag_and_update_pred state_update_predicate_login)
      all_session_updates_login
  );
  ()

val login_has_event_predicate:
  squash (has_event_pred event_predicate_login)
let login_has_event_predicate =
  login_event_predicates_correct;
  for_allP_eq has_compiled_event_pred all_events_login;
  assert_norm (memP (mk_event_tag_and_pred event_predicate_login) all_events_login);
  ()

val login_has_pki_predicates:
  squash (has_pki_invariant /\ has_pki_state_update_invariant)
let login_has_pki_predicates =
  login_state_predicates_correct;
  for_allP_eq has_local_bytes_state_predicate all_sessions_login;
  assert_norm (memP pki_tag_and_invariant all_sessions_login);
  login_state_update_predicates_correct;
  for_allP_eq has_local_bytes_state_update_predicate all_session_updates_login;
  assert_norm (memP pki_tag_and_state_update_pred all_session_updates_login);
  ()

val login_has_private_key_predicates:
  squash (has_private_keys_invariant /\ has_private_keys_state_update_invariant)
let login_has_private_key_predicates =
  login_state_predicates_correct;
  for_allP_eq has_local_bytes_state_predicate all_sessions_login;
  assert_norm (memP private_keys_tag_and_invariant all_sessions_login);
  login_state_update_predicates_correct;
  for_allP_eq has_local_bytes_state_update_predicate all_session_updates_login;
  assert_norm (
    memP private_keys_tag_and_state_update_pred all_session_updates_login
  );
  ()

val login_has_username_request_predicate:
  squash (
    has_web_types_request_key_pred
      (|"username", wt_send_request_pred_key_username|)
  )
let login_has_username_request_predicate = ()

val login_has_wt_send_request_pred_key_password:
  squash (
    has_web_types_request_key_pred
      (|"password", wt_send_request_pred_key_password|)
  )
let login_has_wt_send_request_pred_key_password = ()

val login_has_id_response_predicate:
  squash (
    has_web_types_response_key_pred
      (|"id", wt_send_request_pred_key_true "id"|)
  )
let login_has_id_response_predicate = ()

val login_has_username_response_predicate:
  squash (
    has_web_types_response_key_pred
      (|"username", wt_send_request_pred_key_true "username"|)
  )
let login_has_username_response_predicate = ()

val login_has_email_response_predicate:
  squash (
    has_web_types_response_key_pred
      (|"email", wt_send_request_pred_key_true "email"|)
  )
let login_has_email_response_predicate = ()

val login_has_first_name_response_predicate:
  squash (
    has_web_types_response_key_pred
      (|"firstName", wt_send_request_pred_key_true "firstName"|)
  )
let login_has_first_name_response_predicate = ()

val login_has_last_name_response_predicate:
  squash (
    has_web_types_response_key_pred
      (|"lastName", wt_send_request_pred_key_true "lastName"|)
  )
let login_has_last_name_response_predicate = ()

#pop-options
*)
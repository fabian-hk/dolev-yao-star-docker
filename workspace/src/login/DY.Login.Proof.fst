module DY.Login.Proof

open Comparse
open FStar.List.Tot { for_allP }
open DY.Core
open DY.Lib

open DY.Lib.Web
open DY.Lib.Web.HTTP.Invariants
open DY.Lib.Web.Data.Default.Invariants

open DY.Login.Protocol
open DY.Login.Invariants

#set-options "--fuel 0 --ifuel 0 --z3cliopt 'smt.qi.eager_threshold=100'"

(*** Request facts ***)

#push-options "--fuel 4 --z3rlimit 40"
val build_login_request_proof:
  tr:trace -> client:principal -> password:bytes ->
  Lemma
  (requires (
    let server = domain_to_principal ["dummyjson"; "com"] in
    is_secret (comm_label client server) tr password
  ))
  (ensures (
    let (url, http_req) = build_login_request client password in
    let server = domain_to_principal url.domain in
    domain_to_principal ["dummyjson"; "com"] == server /\
    get_user_agent_header http_req.headers == Some Server /\
    http_query_predicates_login.http_query_pred
      tr client server http_req (comm_label client server) /\
    http_request_headers_properties
      tr client server http_req (comm_label client server) /\
    body_preds_web_types.http_body_request_pred
      tr client server http_req (comm_label client server) /\
    is_well_formed
      (http_request_t web_types kv_types)
      (is_knowable_by (comm_label client server) tr)
      http_req
  ))
let build_login_request_proof tr client password =
  reveal_opaque (`%build_login_request) build_login_request;
  let url:url_t kv_types = {
    protocol = HTTPS;
    domain = ["dummyjson"; "com"];
    port = 443;
    path = "/auth/login";
    query = [];
    fragment = {identifier = ""; data = []};
  } in
  let server = domain_to_principal url.domain in
  let lab = comm_label client server in
  let headers:list (header_t kv_types) = [
    UserAgent Server;
    ContentType "application/json"
  ] in
  let json_lst = [
    {key = "username"; value = VP client};
    {key = "password"; value = VB password}
  ] in
  let body = JSON json_lst in
  let http_req = mk_http_request POST url headers body in
  mk_http_request_body_eq POST url headers body;
  mk_http_request_query_eq POST url headers body;
  mk_http_request_headers_extractable tr POST url headers body;
  assert (
    wt_send_request_pred_key_username.pred
      tr client server lab http_req
  );
  assert (
    wt_send_request_pred_key_password.pred
      tr client server lab http_req
  );
  web_types_request_key_pred_implies_global_pred
    tr "username" wt_send_request_pred_key_username client server http_req;
  web_types_request_key_pred_implies_global_pred
    tr "password" wt_send_request_pred_key_password client server http_req;
  assert (
    for_allP_web_types
      (web_types_predicates_login.wt_send_request_pred.pred
        tr client server lab http_req)
      body
  );
  forall_web_types_request_preds_implies_comm_reqres_preds_lemma
    tr client server url POST headers body;
  assert (is_knowable_by lab tr password);
  assert (for_allP (is_knowable_by_web_kv lab tr) (JSON?._0 body));
  web_types_serialization_lemma tr body lab;
  assert (for_allP (is_knowable_by_header lab tr) headers);
  assert (for_allP (is_knowable_by_key_value lab tr) url.query);
  mk_http_request_knowable tr client POST url headers body;
  ()
#pop-options

(*** Response facts ***)

#push-options "--fuel 6 --z3rlimit 40"
val build_login_response_proof:
  tr:trace -> hmeta_data:http_meta_data web_types kv_types ->
  Lemma
  (ensures (
    let http_res = build_login_response () in
    let http_req = Request?.http_req hmeta_data.request in
    is_well_formed
      (http_response_t web_types kv_types)
      (is_knowable_by (get_response_label tr hmeta_data) tr)
      http_res /\
    body_preds_web_types.http_body_response_pred
      tr hmeta_data.client hmeta_data.server http_req http_res
      (get_response_label tr hmeta_data) /\
    http_response_properties
      tr hmeta_data.client hmeta_data.server http_req http_res
      (get_response_label tr hmeta_data)
  ))
let build_login_response_proof tr hmeta_data =
  reveal_opaque (`%build_login_response) build_login_response;
  let headers:list (header_t kv_types) = [
    ContentType "application/json"
  ] in
  let body = JSON [
    {key = "id"; value = VI 1};
    {key = "username"; value = VS "emilys"};
    {key = "email"; value = VS "emily.johnson@x.dummyjson.com"};
    {key = "firstName"; value = VS "Emily"};
    {key = "lastName"; value = VS "Johnson"}
  ] in
  let http_res = mk_http_response 200 headers body in
  let http_req = Request?.http_req hmeta_data.request in
  let lab = get_response_label tr hmeta_data in
  assert (for_allP (is_knowable_by_web_kv lab tr) (JSON?._0 body));
  web_types_serialization_lemma tr body lab;
  assert (for_allP (is_knowable_by_header lab tr) headers);
  mk_http_response_knowable
    tr hmeta_data.server hmeta_data 200 headers body;
  web_types_response_key_pred_implies_global_pred
    tr "id" (wt_send_request_pred_key_true "id")
    hmeta_data http_req http_res;
  web_types_response_key_pred_implies_global_pred
    tr "username" (wt_send_request_pred_key_true "username")
    hmeta_data http_req http_res;
  web_types_response_key_pred_implies_global_pred
    tr "email" (wt_send_request_pred_key_true "email")
    hmeta_data http_req http_res;
  web_types_response_key_pred_implies_global_pred
    tr "firstName" (wt_send_request_pred_key_true "firstName")
    hmeta_data http_req http_res;
  web_types_response_key_pred_implies_global_pred
    tr "lastName" (wt_send_request_pred_key_true "lastName")
    hmeta_data http_req http_res;
  assert (
    for_allP_web_types
      (web_types_predicates_login.wt_send_response_pred.pred
        tr hmeta_data.server lab http_req http_res)
      body
  );
  forall_web_types_response_preds_implies_comm_reqres_preds_lemma
    tr hmeta_data 200 headers body
#pop-options

(*** Trace-invariant preservation proofs ***)

#push-options "--ifuel 1 --z3rlimit 40"
val api_request_proof:
  tr:trace -> comm_keys_ids:communication_keys_sess_ids ->
  client:principal -> sid:state_id ->
  Lemma
  (requires
    trace_invariant tr /\
    has_communication_layer_reqres_predicates (http_t web_types kv_types)
  )
  (ensures (
    let (_, tr_out) = api_request comm_keys_ids client sid tr in
    trace_invariant tr_out
  ))
let api_request_proof tr comm_keys_ids client sid =
  reveal_opaque (`%api_request) (api_request comm_keys_ids client sid);
  let (_, tr_out) = api_request comm_keys_ids client sid tr in
  let (opt_state, _) = get_state #state_t client sid tr in
  match opt_state with
  | None -> ()
  | Some (SendRequest _) -> ()
  | Some (InitialState state_client server password) ->
    let (opt_client, _) = guard_tr (client = state_client) tr in
    match opt_client with
    | None -> ()
    | Some _ ->
      let (opt_server, _) = guard_tr
        (server = domain_to_principal ["dummyjson"; "com"]) tr in
      match opt_server with
      | None -> ()
      | Some _ ->
        let (url, http_req) = build_login_request client password in
        build_login_request_proof tr client password;
        send_https_request_proof tr comm_keys_ids client url http_req;
        match send_https_request comm_keys_ids client url http_req tr with
        | (Some (_, hmeta_data), tr_sent) ->
          derive_comm_meta_data_knowable_client tr_sent hmeta_data client;
          let (new_sid, tr_sid) = new_session_id client tr_sent in
          set_state_invariant
            state_predicate_login state_update_predicate_login
            client new_sid (SendRequest hmeta_data) tr_sid;
          assert (trace_invariant tr_out)
        | _ -> ()
#pop-options

val authenticated_login_request_condition:
  trace -> communication_keys_sess_ids -> principal -> state_id ->
  timestamp -> prop
let authenticated_login_request_condition
    tr comm_keys_ids server sid msg_id =
  match get_state #state_t server sid tr with
  | (Some (InitialState client _ _), _) ->
    (match receive_https_request comm_keys_ids server msg_id tr with
    | (Some (http_req, hmeta_data), tr_received) ->
      event_triggered tr_received client (CommClientSendRequest Unauthenticated client server (Request http_req) hmeta_data.key <: communication_reqres_event (http_t web_types kv_types))
    | _ -> True)
  | _ -> True

#push-options "--z3rlimit 40"
val authenticated_login_response_proof:
  tr:trace -> client:principal -> server:principal ->
  http_req:http_request_t web_types kv_types ->
  hmeta_data:http_meta_data web_types kv_types ->
  Lemma
  (requires
    trace_invariant tr /\
    has_communication_layer_reqres_predicates (http_t web_types kv_types) /\
    hmeta_data.server == server /\
    event_triggered tr server
      (CommServerReceiveRequest
        hmeta_data.client server hmeta_data.request hmeta_data.key
        <: communication_reqres_event (http_t web_types kv_types)) /\
    event_triggered tr client (CommClientSendRequest Unauthenticated client server (Request http_req) hmeta_data.key <: communication_reqres_event (http_t web_types kv_types))
  )
  (ensures (
    let login_event = ServerAuthenticatedUser client server http_req hmeta_data.key in
    let ((), tr_event) = trigger_event server login_event tr in
    match send_https_response server hmeta_data (build_login_response ()) tr_event with
    | (None, tr_out) -> trace_invariant tr_out
    | (Some msg_id_out, tr_sent) ->
      let (_, tr_out) = return (Some msg_id_out) tr_sent in
      trace_invariant tr_out
  ))
let authenticated_login_response_proof
    tr client server http_req hmeta_data =
  let login_event =
    ServerAuthenticatedUser client server http_req hmeta_data.key in
  assert (event_predicate_login tr server login_event);
  trigger_event_trace_invariant event_predicate_login server login_event tr;
  let ((), tr_event) = trigger_event server login_event tr in
  event_triggered_grows
    tr tr_event server
    (CommServerReceiveRequest
      hmeta_data.client server hmeta_data.request hmeta_data.key
      <: communication_reqres_event (http_t web_types kv_types));
  build_login_response_proof tr_event hmeta_data;
  send_https_response_proof tr_event server hmeta_data (build_login_response ())
#pop-options

#push-options "--ifuel 1 --z3rlimit 40"
val api_server_proof:
  tr:trace -> comm_keys_ids:communication_keys_sess_ids ->
  server:principal -> sid:state_id -> msg_id:timestamp ->
  Lemma
  (requires
    trace_invariant tr /\
    has_communication_layer_reqres_predicates (http_t web_types kv_types) /\
    // TODO remove this precondition as it should be proven from receiving the message and state invariant
    authenticated_login_request_condition
      tr comm_keys_ids server sid msg_id
  )
  (ensures (
    let (_, tr_out) = api_server comm_keys_ids server sid msg_id tr in
    trace_invariant tr_out
  ))
let api_server_proof tr comm_keys_ids server sid msg_id =
  assert_norm (
    protocol_invariants_login.crypto_invs.usages == default_crypto_usages
  );
  reveal_opaque (`%api_server) (api_server comm_keys_ids server sid msg_id);
  let (_, tr_out) = api_server comm_keys_ids server sid msg_id tr in
  let (opt_state, _) = get_state #state_t server sid tr in
  match opt_state with
  | None -> ()
  | Some (SendRequest _) -> ()
  | Some (InitialState client state_server password) ->
    let (opt_server, _) = guard_tr (server = state_server) tr in
    match opt_server with
    | None -> ()
    | Some _ ->
      receive_https_request_proof
        #protocol_invariants_login #web_types #kv_types
        tr comm_keys_ids server msg_id;
      let (opt_request, tr_received) =
        receive_https_request comm_keys_ids server msg_id tr in
      match opt_request with
      | Some (http_req, hmeta_data) ->
        let (credentials_match, tr_credentials) =
          guard_tr
            (login_request_credentials_match client password http_req)
            tr_received in
        (match credentials_match with
        | None -> ()
        | Some _ ->
          authenticated_login_response_proof
            tr_credentials client server http_req hmeta_data;
          assert (trace_invariant tr_out))
      | _ -> ()
#pop-options

#push-options "--ifuel 1 --z3rlimit 20"
val api_response_proof:
  tr:trace -> client:principal -> sid:state_id -> msg_id:timestamp ->
  Lemma
  (requires
    trace_invariant tr /\
    has_communication_layer_reqres_predicates (http_t web_types kv_types)
  )
  (ensures (
    let (_, tr_out) = api_response client sid msg_id tr in
    trace_invariant tr_out
  ))
let api_response_proof tr client sid msg_id =
  reveal_opaque (`%api_response) (api_response client sid msg_id);
  let (_, tr_out) = api_response client sid msg_id tr in
  match get_state #state_t client sid tr with
  | (Some (SendRequest hmeta_data), _) ->
    receive_https_response_proof tr hmeta_data client msg_id;
    assert (trace_invariant tr_out)
  | _ -> ()
#pop-options

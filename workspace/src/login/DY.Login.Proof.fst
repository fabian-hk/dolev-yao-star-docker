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

(*** API Request ***)

#push-options "--fuel 4 --z3rlimit 40"
val build_login_request_proof:
  tr:trace -> client:principal -> password:bytes ->
  Lemma
  (requires (
    let server = domain_to_principal ["dummyjson"; "com"] in
    is_secret (comm_label client server) tr password /\
    event_triggered tr client (ClientAuthenticatesToServer client server)
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

#push-options "--ifuel 1 --z3rlimit 20"
val api_request_proof:
  tr:trace -> comm_keys_ids:communication_keys_sess_ids ->
  client:principal -> sid:state_id ->
  Lemma
  (requires
    trace_invariant tr
  )
  (ensures (
    let (_, tr_out) = api_request comm_keys_ids client sid tr in
    trace_invariant tr_out
  ))
let api_request_proof tr comm_keys_ids client sid =
  reveal_opaque (`%api_request) (api_request comm_keys_ids client sid);
  let (_, tr_out) = api_request comm_keys_ids client sid tr in

  let (opt_state, tr_get) = get_state #state_t client sid tr in
  assert(trace_invariant tr_get);
  match opt_state with
  | None -> ()
  | Some (SendRequest _) -> ()
  | Some (InitialState state_client server password) ->
    let (opt_client, tr_gd1) = guard_tr (client = state_client) tr_get in
    match opt_client with
    | None -> ()
    | Some _ ->
      let ((), tr_event) = trigger_event client (ClientAuthenticatesToServer client server) tr_gd1 in
      assert(trace_invariant tr_event);
      let (url, http_req) = build_login_request client password in
      let (opt_server, tr_gd2) = guard_tr (server = http_config_login.domain_to_principal url.domain) tr_event in
      match opt_server with
      | None -> ()
      | Some _ ->
        assert(tr_event == tr_gd2);
        let server = http_config_login.domain_to_principal url.domain in
        build_login_request_proof tr_gd2 client password;
        send_https_request_proof tr_gd2 comm_keys_ids client url http_req;
        match send_https_request comm_keys_ids client url http_req tr_gd2 with
        | (None, tr_sent) -> ()
        | (Some (_, hmeta_data), tr_sent) ->
          derive_comm_meta_data_knowable_client tr_sent hmeta_data client;
          let (new_sid, tr_sid) = new_session_id client tr_sent in
          let ((), tr_st) = set_state client sid (SendRequest hmeta_data) tr_sid in
          set_state_invariant state_predicate_login state_update_predicate_login client new_sid (SendRequest hmeta_data) tr_sid;
          assert (trace_invariant tr_out)
#pop-options


(*** API Server ***)

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

#push-options "--z3rlimit 20"
val helper_lemma_event_invariant:
  tr:trace -> client:principal -> server:principal ->
  http_req:http_request_t web_types kv_types ->
  hmeta_data:http_meta_data web_types kv_types ->
  password:bytes ->
  Lemma
  (requires
    trace_invariant tr /\
    hmeta_data.server == server /\
    hmeta_data.client == None /\
    hmeta_data.request == Request http_req /\
    event_triggered tr server (CommServerReceiveRequest hmeta_data.client server hmeta_data.request hmeta_data.key <: communication_reqres_event (http_t web_types kv_types)) /\
    get_bytes_from_json_encoded "password" http_req.body == Some password /\
    get_principal_from_json_encoded "username" http_req.body == Some client /\
    is_secret (comm_label client server) tr password /\
    is_server_request http_req
  )
  (ensures (
    event_predicate_login tr server (ServerAuthenticatedClient client server)
  ))
let helper_lemma_event_invariant tr client server http_req hmeta_data password =
  eliminate (exists client. event_triggered tr client (CommClientSendRequest Unauthenticated client server hmeta_data.request hmeta_data.key <: communication_reqres_event (http_t web_types kv_types))) \/
    (is_publishable tr hmeta_data.key /\ is_well_formed (http_t web_types kv_types) (is_publishable tr) hmeta_data.request)
  returns event_triggered tr client (ClientAuthenticatesToServer client server) \/
    is_corrupt tr (principal_label client) \/ is_corrupt tr (principal_label server)
  with _. (
    eliminate exists client. event_triggered tr client (CommClientSendRequest Unauthenticated client server hmeta_data.request hmeta_data.key <: communication_reqres_event (http_t web_types kv_types))
    returns event_triggered tr client (ClientAuthenticatesToServer client server) \/
      is_corrupt tr (principal_label client) \/ is_corrupt tr (principal_label server)
    with _. (
      web_types_request_predicate tr "username" wt_send_request_pred_key_username hmeta_data client;
      ()
    )
  )
  and _. (
    assert(is_well_formed web_types (is_publishable tr) http_req.body);
    get_bytes_from_json_encoded_knowable tr public "password" http_req.body;
    assert(is_publishable tr password);
    ()
  )
#pop-options

#push-options "--ifuel 1 --z3rlimit 40"
val api_server_proof:
  tr:trace -> comm_keys_ids:communication_keys_sess_ids ->
  server:principal -> sid:state_id -> msg_id:timestamp ->
  Lemma
  (requires
    trace_invariant tr
  )
  (ensures (
    let (_, tr_out) = api_server comm_keys_ids server sid msg_id tr in
    trace_invariant tr_out
  ))
let api_server_proof tr comm_keys_ids server sid msg_id =
  reveal_opaque (`%api_server) (api_server comm_keys_ids server sid msg_id);
  let (_, tr_out) = api_server comm_keys_ids server sid msg_id tr in
  let (opt_state, tr_get) = get_state #state_t server sid tr in
  match opt_state with
  | None -> ()
  | Some (SendRequest _) -> ()
  | Some (InitialState client state_server password) ->
    let (opt_server, tr_gd1) = guard_tr (server = state_server) tr_get in
    match opt_server with
    | None -> ()
    | Some _ ->
      receive_https_request_proof #protocol_invariants_login #web_types #kv_types tr_gd1 comm_keys_ids server msg_id;
      let (opt_request, tr_received) = receive_https_request comm_keys_ids server msg_id tr_gd1 in
      match opt_request with
      | None -> ()
      | Some (http_req, hmeta_data) ->
        let (opt_user_agent, tr_gd2) = guard_tr (get_user_agent_header http_req.headers = Some Server) tr_received in
        match opt_user_agent with
        | None -> ()
        | Some _ ->
          let (credentials_match, tr_gd3) = guard_tr (login_request_credentials_match client password http_req) tr_gd2 in
          match credentials_match with
          | None -> ()
          | Some _ ->
            let ((), tr_event) = trigger_event server (ServerAuthenticatedClient client server) tr_gd3 in
            helper_lemma_event_invariant tr_gd3 client server http_req hmeta_data password;
            assert(trace_invariant tr_event);
            
            let (_, tr_snd) = send_https_response server hmeta_data (build_login_response ()) tr_event in
            build_login_response_proof tr_event hmeta_data;
            send_https_response_proof tr_event server hmeta_data (build_login_response ());
            assert(trace_invariant tr_snd);
            assert (tr_snd == tr_out);
            ()
#pop-options


(*** API Response ***)

#push-options "--ifuel 1 --z3rlimit 20"
val api_response_proof:
  tr:trace -> client:principal -> sid:state_id -> msg_id:timestamp ->
  Lemma
  (requires
    trace_invariant tr
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

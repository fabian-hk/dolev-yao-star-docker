module DY.Login.Proof.Helpers

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

(*** API Request Proof Helpers ***)

#push-options "--fuel 4 --z3rlimit 40"
val build_login_request_proof:
  tr:trace -> client:principal -> domain:domain_t -> password:bytes ->
  Lemma
  (requires (
    let server = domain_to_principal domain in
    is_secret (comm_label client server) tr password /\
    event_triggered tr client (ClientAuthenticatesToServer client server)
  ))
  (ensures (
    let (url, http_req) = build_login_request client domain password in
    let server = domain_to_principal url.domain in
    domain_to_principal domain == server /\
    get_user_agent_header http_req.headers == Some Server /\
    http_query_predicates_login.http_query_pred tr client server http_req (comm_label client server) /\
    http_request_headers_properties tr client server http_req (comm_label client server) /\
    body_preds_web_types.http_body_request_pred tr client server http_req (comm_label client server) /\
    is_well_formed (http_request_t web_types kv_types) (is_knowable_by (comm_label client server) tr) http_req /\
    is_server_request http_req
  ))
let build_login_request_proof tr client domain password =
  reveal_opaque (`%build_login_request) build_login_request;
  let url:url_t kv_types = {
    protocol = HTTPS;
    domain = domain;
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

  assert(is_server_request http_req);

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

val helper_lemma_state_invariant_send_request:
  tr:trace -> client:principal -> sid:state_id -> hmeta_data:http_meta_data web_types kv_types ->
  Lemma
  (requires (
    trace_invariant tr /\ 
    event_triggered tr client (CommClientSendRequest Unauthenticated client hmeta_data.server hmeta_data.request hmeta_data.key <: communication_reqres_event (http_t web_types kv_types)) /\
    is_server_request (Request?.http_req hmeta_data.request)
  ))
  (ensures (
    state_predicate_login.pred tr client sid (SendRequest hmeta_data)
  ))
let helper_lemma_state_invariant_send_request tr client sid hmeta_data = ()


(*** API Server Proof Helpers ***)

#restart-solver
#push-options "--fuel 6 --z3rlimit 40"
val build_login_response_proof:
  tr:trace -> hmeta_data:http_meta_data web_types kv_types ->
  client:principal -> cookie:cookie_t ->
  Lemma
  (requires
    event_triggered tr hmeta_data.server (ServerAuthenticatedClient client hmeta_data.server cookie) /\
    is_secret (get_response_label tr hmeta_data) tr cookie.value /\
    cookie.secure == true /\
    Some? (get_set_cookie_header "accessToken" [SetCookie cookie <: header_t kv_types])
  )
  (ensures (
    let http_res = build_login_response client cookie in
    let http_req = Request?.http_req hmeta_data.request in
    is_well_formed (http_response_t web_types kv_types) (is_knowable_by (get_response_label tr hmeta_data) tr) http_res /\
    body_preds_web_types.http_body_response_pred tr hmeta_data.client hmeta_data.server http_req http_res (get_response_label tr hmeta_data) /\
    http_response_properties tr hmeta_data.client hmeta_data.server http_req http_res (get_response_label tr hmeta_data)
  ))
let build_login_response_proof tr hmeta_data client cookie =
  reveal_opaque (`%build_login_response) build_login_response;
  let headers:list (header_t kv_types) = [
    ContentType "application/json";
    SetCookie cookie
  ] in
  let body = JSON [
    {key = "id"; value = VI 1};
    {key = "username"; value = VS client};
    {key = "email"; value = VS "emily.johnson@x.dummyjson.com"};
    {key = "firstName"; value = VS "Emily"};
    {key = "lastName"; value = VS "Johnson"}
  ] in
  let http_res = mk_http_response 200 headers body in
  let http_req = Request?.http_req hmeta_data.request in
  
  // Proving is_well_formed
  let lab = get_response_label tr hmeta_data in
  assert (for_allP (is_knowable_by_web_kv lab tr) (JSON?._0 body));
  web_types_serialization_lemma tr body lab;
  assert (for_allP (is_knowable_by_header lab tr) headers);
  mk_http_response_knowable tr hmeta_data.server hmeta_data 200 headers body;
  assert(is_well_formed (http_response_t web_types kv_types) (is_knowable_by lab tr) http_res);
  
  // Proving body_preds_web_types.http_body_response_pred
  web_types_response_key_pred_implies_global_pred tr "id" (wt_send_response_pred_key_true "id") hmeta_data http_req http_res;
  web_types_response_key_pred_implies_global_pred tr "username" (wt_send_response_pred_key_username) hmeta_data http_req http_res;
  web_types_response_key_pred_implies_global_pred tr "email" (wt_send_response_pred_key_true "email") hmeta_data http_req http_res;
  web_types_response_key_pred_implies_global_pred tr "firstName" (wt_send_response_pred_key_true "firstName") hmeta_data http_req http_res;
  web_types_response_key_pred_implies_global_pred tr "lastName" (wt_send_response_pred_key_true "lastName") hmeta_data http_req http_res;
  assert (for_allP_web_types (web_types_predicates_login.wt_send_response_pred.pred tr hmeta_data.server lab http_req http_res) body);
  forall_web_types_response_preds_implies_comm_reqres_preds_lemma tr hmeta_data 200 headers body;
  assert(body_preds_web_types.http_body_response_pred tr hmeta_data.client hmeta_data.server http_req http_res lab);
  
  // Proving http_response_properties
  assert(for_allP (http_response_header_properties tr hmeta_data.client hmeta_data.server http_req http_res lab) headers) by (
    let open FStar.Tactics in
    norm [delta_only [`%for_allP; `%http_response_header_properties]; iota; zeta];
    ()
  );
  mk_http_response_headers_extractable 200 headers body;
  assert(for_allP (http_response_header_properties tr hmeta_data.client hmeta_data.server http_req http_res lab) http_res.headers);
  assert(http_response_properties tr hmeta_data.client hmeta_data.server http_req http_res lab);
  ()
#pop-options

#push-options "--z3rlimit 20"
val helper_lemma_event_invariant_server_authenticated_client:
  tr:trace -> client:principal -> server:principal ->
  http_req:http_request_t web_types kv_types ->
  hmeta_data:http_meta_data web_types kv_types ->
  password:bytes ->
  cookie:cookie_t ->
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
    is_server_request http_req /\
    is_secret (get_response_label tr hmeta_data) tr cookie.value
  )
  (ensures (
    event_predicate_login tr server (ServerAuthenticatedClient client server cookie)
  ))
let helper_lemma_event_invariant_server_authenticated_client tr client server http_req hmeta_data password cookie =
  eliminate (exists client. event_triggered tr client (CommClientSendRequest Unauthenticated client server hmeta_data.request hmeta_data.key <: communication_reqres_event (http_t web_types kv_types))) \/
    (is_publishable tr hmeta_data.key /\ is_well_formed (http_t web_types kv_types) (is_publishable tr) hmeta_data.request)
  returns (event_triggered tr client (ClientAuthenticatesToServer client server) /\
        is_secret (comm_label client server) tr cookie.value) \/
    is_corrupt tr (principal_label client) \/ is_corrupt tr (principal_label server)
  with _. (
    eliminate exists client. event_triggered tr client (CommClientSendRequest Unauthenticated client server hmeta_data.request hmeta_data.key <: communication_reqres_event (http_t web_types kv_types))
    returns (event_triggered tr client (ClientAuthenticatesToServer client server) /\
        is_secret (comm_label client server) tr cookie.value) \/
      is_corrupt tr (principal_label client) \/ is_corrupt tr (principal_label server)
    with _. (
      web_types_request_predicate tr "username" wt_send_request_pred_key_username hmeta_data client;
      get_response_label_eq_key_label tr hmeta_data;
      ()
    )
  )
  and _. (
    assert(is_well_formed web_types (is_publishable tr) http_req.body);
    get_bytes_from_json_encoded_knowable tr public "password" http_req.body;
    ()
  )
#pop-options


(*** API Response Proof Helpers ***)

#restart-solver
#push-options "--z3rlimit 20"
val helper_lemma_event_invariant_client_received_cookie:
  tr:trace -> client:principal -> hmeta_data:http_meta_data web_types kv_types -> http_res:http_response_t web_types kv_types -> cookie:cookie_t ->
  Lemma
  (requires
    trace_invariant tr /\
    get_set_cookie_header "accessToken" http_res.headers == Some cookie /\
    get_string_from_json_encoded "username" http_res.body == Some client /\
    is_server_request (Request?.http_req hmeta_data.request) /\
    cookie.secure == true /\
    event_triggered tr client (CommClientReceiveResponse client (Response http_res) hmeta_data <: communication_reqres_event (http_t web_types kv_types)) /\
    event_triggered tr client (CommClientSendRequest (request_authenticated hmeta_data) client hmeta_data.server hmeta_data.request hmeta_data.key <: communication_reqres_event (http_t web_types kv_types))
  )
  (ensures (
    event_predicate_login tr client (ClientReceivedCookie client hmeta_data.server cookie)
  ))
let helper_lemma_event_invariant_client_received_cookie tr client hmeta_data http_res cookie =
  response_message_properties tr client (Response http_res) hmeta_data;
  eliminate event_triggered tr hmeta_data.server (CommServerSendResponse hmeta_data.client hmeta_data.server hmeta_data.request (Response http_res) hmeta_data.key <: communication_reqres_event (http_t web_types kv_types)) \/
    (is_corrupt tr (principal_label client) \/ is_corrupt tr (principal_label hmeta_data.server))
  returns (event_triggered tr hmeta_data.server (ServerAuthenticatedClient client hmeta_data.server cookie) /\
        is_secret (comm_label client hmeta_data.server) tr cookie.value) \/
       is_corrupt tr (principal_label client) \/ is_corrupt tr (principal_label hmeta_data.server)
  with _. (
    let http_req = Request?.http_req hmeta_data.request in
    comm_server_send_response_implies_set_cookie_properties tr client hmeta_data http_res "accessToken" cookie;
    send_request_event_properties tr client hmeta_data;
    web_types_response_predicate tr "username" wt_send_response_pred_key_username hmeta_data client http_res;
    ()
  )
  and _. ()
#pop-options

#push-options "--ifuel 1 --z3rlimit 40"
val process_login_response_proof:
  client:principal -> http_res:http_response_t web_types kv_types -> 
  Lemma
  (ensures (
    let opt_cookie = process_login_response client http_res in
    match opt_cookie with
    | Some cookie -> get_set_cookie_header "accessToken" http_res.headers == Some cookie /\
      get_string_from_json_encoded "username" http_res.body == Some client /\
      cookie.secure == true
    | None -> True
  ))
let process_login_response_proof client http_res = ()
#pop-options

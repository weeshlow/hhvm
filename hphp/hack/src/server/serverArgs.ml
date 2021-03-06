(**
 * Copyright (c) 2015, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the "hack" directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *
 *)

(*****************************************************************************)
(* The options from the command line *)
(*****************************************************************************)

type options = {
  ai_mode          : Ai_options.t option;
  check_mode       : bool;
  json_mode        : bool;
  root             : Path.t;
  should_detach    : bool;
  convert          : Path.t option;
  max_procs        : int;
  no_load          : bool;
  save_filename    : string option;
  waiting_client   : Unix.file_descr option;
  debug_client     : Handle.handle option;
}

(*****************************************************************************)
(* Usage code *)
(*****************************************************************************)
let usage = Printf.sprintf "Usage: %s [WWW DIRECTORY]\n" Sys.argv.(0)

(*****************************************************************************)
(* Options *)
(*****************************************************************************)

module Messages = struct
  let debug         = " debugging mode"
  let ai            = " run ai with options"
  let check         = " check and exit"
  let json          = " output errors in json format (arc lint mode)"
  let daemon        = " detach process"
  let from_vim      = " passed from hh_client"
  let from_emacs    = " passed from hh_client"
  let from_hhclient = " passed from hh_client"
  let convert       = " adds type annotations automatically"
  let save          = " DEPRECATED"
  let save_mini     = " save mini server state to file"
  let max_procs     = " max numbers of workers"
  let no_load       = " don't load from a saved state"
  let waiting_client= " send message to fd/handle when server has begun \
                      \ starting and again when it's done starting"
  let debug_client  = " send significant server events to this file descriptor"
end

let print_json_version () =
  let open Hh_json in
  let json = JSON_Object [
    "commit", JSON_String Build_id.build_revision;
    "commit_time", int_ Build_id.build_commit_time;
    "api_version", int_ Build_id.build_api_version;
  ] in
  print_endline @@ json_to_string json

(*****************************************************************************)
(* The main entry point *)
(*****************************************************************************)

let parse_options () =
  let root          = ref "" in
  let from_vim      = ref false in
  let from_emacs    = ref false in
  let from_hhclient = ref false in
  let debug         = ref false in
  let ai_mode       = ref None in
  let check_mode    = ref false in
  let json_mode     = ref false in
  let should_detach = ref false in
  let convert_dir   = ref None  in
  let save          = ref None in
  let max_procs     = ref GlobalConfig.nbr_procs in
  let no_load       = ref false in
  let version       = ref false in
  let waiting_client= ref None in
  let debug_client  = ref None in
  let cdir          = fun s -> convert_dir := Some s in
  let set_ai        = fun s -> ai_mode := Some (Ai_options.prepare ~server:true s) in
  let set_max_procs = fun s -> max_procs := min !max_procs s in
  let set_save ()   = Printf.eprintf "DEPRECATED\n"; exit 1 in
  let set_save_mini = fun s -> save := Some s in
  let set_wait      = fun fd -> waiting_client := Some (Handle.wrap_handle fd) in
  let set_debug = fun fd -> debug_client := Some fd in
  let options =
    ["--debug"         , Arg.Set debug         , Messages.debug;
     "--ai"            , Arg.String set_ai     , Messages.ai;
     "--check"         , Arg.Set check_mode    , Messages.check;
     "--json"          , Arg.Set json_mode     , Messages.json; (* CAREFUL!!! *)
     "--daemon"        , Arg.Set should_detach , Messages.daemon;
     "-d"              , Arg.Set should_detach , Messages.daemon;
     "--from-vim"      , Arg.Set from_vim      , Messages.from_vim;
     "--from-emacs"    , Arg.Set from_emacs    , Messages.from_emacs;
     "--from-hhclient" , Arg.Set from_hhclient , Messages.from_hhclient;
     "--convert"       , Arg.String cdir       , Messages.convert;
     "--save"          , Arg.Unit set_save     , Messages.save;
     "--save-mini"     , Arg.String set_save_mini, Messages.save_mini;
     "--max-procs"     , Arg.Int set_max_procs , Messages.max_procs;
     "--no-load"       , Arg.Set no_load       , Messages.no_load;
     "--version"       , Arg.Set version       , "";
     "--waiting-client", Arg.Int set_wait      , Messages.waiting_client;
     "--debug-client"  , Arg.Int set_debug     , Messages.debug_client;
    ] in
  let options = Arg.align options in
  Arg.parse options (fun s -> root := s) usage;
  if !version then begin
    if !json_mode then print_json_version ()
    else print_endline Build_id.build_id_ohai;
    exit 0
  end;
  (* --json and --save both imply check *)
  let check_mode = !check_mode || !json_mode || !save <> None; in
  (* Conversion mode implies check *)
  let check_mode = check_mode || !convert_dir <> None in
  let convert = Option.map ~f:Path.make !convert_dir in
  if check_mode && !waiting_client <> None then begin
    Printf.eprintf "--check is incompatible with wait modes!\n";
    Exit_status.(exit Input_error)
  end;
  (match !root with
  | "" ->
      Printf.eprintf "You must specify a root directory!\n";
      Exit_status.(exit Input_error)
  | _ -> ());
  let root_path = Path.make !root in
  Wwwroot.assert_www_directory root_path;
  {
    json_mode     = !json_mode;
    ai_mode       = !ai_mode;
    check_mode    = check_mode;
    root          = root_path;
    should_detach = !should_detach;
    convert       = convert;
    max_procs     = !max_procs;
    no_load       = !no_load;
    save_filename = !save;
    waiting_client= !waiting_client;
    debug_client  = !debug_client;
  }

(* useful in testing code *)
let default_options ~root = {
  ai_mode = None;
  check_mode = false;
  json_mode = false;
  root = Path.make root;
  should_detach = false;
  convert = None;
  max_procs = GlobalConfig.nbr_procs;
  no_load = true;
  save_filename = None;
  waiting_client = None;
  debug_client = None;
}

(*****************************************************************************)
(* Accessors *)
(*****************************************************************************)

let ai_mode options = options.ai_mode
let check_mode options = options.check_mode
let json_mode options = options.json_mode
let root options = options.root
let should_detach options = options.should_detach
let convert options = options.convert
let max_procs options = options.max_procs
let no_load options = options.no_load
let save_filename options = options.save_filename
let waiting_client options = options.waiting_client
let debug_client options = options.debug_client

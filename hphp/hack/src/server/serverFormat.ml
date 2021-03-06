(**
 * Copyright (c) 2015, Facebook, Inc.
 * All rights reserved.
 *
 * This source code is licensed under the BSD-style license found in the
 * LICENSE file in the "hack" directory of this source tree. An additional grant
 * of patent rights can be found in the PATENTS file in the same directory.
 *
 *)

(* TODO t14922604: Further improve error handling *)
let call_external_formatter path content _from _to_ =
  let args = [|"hackfmt"|] in
  let lines = ref [] in
  let reader timeout ic oc =
    output_string oc content;
    close_out oc;
    try while true do lines := Timeout.input_line ~timeout ic :: !lines done
      with End_of_file -> lines := "" :: !lines;
  in
  try
    Timeout.read_process
      ~timeout:2
      ~on_timeout:(fun _ -> Hh_logger.log "Format timed out")
      ~reader
      path
      args;
    Format_hack.Success (String.concat "\n" @@ List.rev !lines)
  with Timeout.Timeout -> Format_hack.Internal_error

let go genv content from to_ =
  if genv.ServerEnv.local_config.ServerLocalConfig.use_hackfmt then
    let path = match ServerConfig.formatter_override genv.ServerEnv.config with
      | None -> Path.make "/usr/local/bin/hackfmt"
      | Some p -> p
    in
    let path = Path.to_string path in
    if Sys.file_exists path
    then call_external_formatter path content from to_
    else Format_hack.Internal_error
  else
    let modes = [Some FileInfo.Mstrict; Some FileInfo.Mpartial] in
    Format_hack.region modes Path.dummy_path from to_ content

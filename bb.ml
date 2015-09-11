open Batteries

(* Config ***************************************)

let rev = 1

let backup_server = "salpiglossis"
let backup_port = 22
let backup_uid = 1000
let backup_cmd =
  [| "rdiff-backup"; "/home/armael"; "data@salpiglossis::/pool/armael/Backups/hummingbird" |]

let token_path = "/var/local/background-backup-token"

let backup_interval = 1 (* hour *) * 3600
let polling_interval = 10 (* minutes *) * 60

(************************************************)

type token = {
  last_backup: float;
}

let load_token () : token option =
  try
    let dat = input_file token_path in
    let tok_rev = Char.code dat.[0] in
    if rev = tok_rev then
      Some (Marshal.from_string dat 1)
    else None
  with Sys_error _ -> None

let write_token (tok: token) =
  let dat = String.make 1 (Char.chr rev) ^ (Marshal.to_string tok []) in
  output_file ~filename:token_path ~text:dat

let has_internet () =
  try
    let addr = (Unix.gethostbyname backup_server).Unix.h_addr_list.(0) in
    let _, _ = Unix.open_connection (Unix.ADDR_INET (addr, backup_port)) in
    true
  with _ ->
    false

let launch_backup () =
  match Unix.fork () with
  | 0 ->
    Unix.setuid backup_uid;
    Unix.execvp backup_cmd.(0) backup_cmd
  | pid ->
    pid

let is_old tok =
  (Unix.time ()) -. tok.last_backup >= float_of_int backup_interval
    
let log = Syslog.openlog "background-backup"

let main () =
  while true do
    if load_token () |> Option.map is_old |? true && has_internet () then (
      Syslog.syslog log `LOG_INFO "Starting a new backup...";
      let start_time = Unix.time () |> int_of_float in
      write_token { last_backup = Unix.time () };
      launch_backup () |> Unix.waitpid [] |> ignore;
      let end_time = Unix.time () |> int_of_float in
      let delay_min = (end_time - start_time) / 60 in
      Syslog.syslog log `LOG_INFO (Printf.sprintf "Finished. (%dh %dmin)"
                                     (delay_min / 60)
                                     (delay_min - 60 * (delay_min / 60)));
    ) else (
      if not (has_internet ()) then (
        Syslog.syslog log `LOG_INFO "Backup server is unreachable."
      ) else (
        Syslog.syslog log `LOG_INFO "Previous backup is recent."
      );
      Unix.sleep polling_interval
    )
  done

let () = main ()

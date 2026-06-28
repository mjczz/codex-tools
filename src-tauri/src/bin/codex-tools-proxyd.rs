fn main() {
    env_logger::Builder::from_env(env_logger::Env::default().default_filter_or("info"))
        .format_timestamp_secs()
        .init();

    if let Err(error) = app_lib::proxy_daemon::run_cli_from_env() {
        eprintln!("{error}");
        std::process::exit(1);
    }
}

[DBus (name = "org.freedesktop.login1.Manager")]
interface LoginManager : Object {
    public signal void prepare_for_shutdown (bool active);

    public signal void prepare_for_sleep (bool active);

    public abstract bool preparing_for_shutdown { get; }
}

LoginManager get_login_manager () {
    return Bus.get_proxy_sync (BusType.SYSTEM, "org.freedesktop.login1", "/org/freedesktop/login1");
}
using GLib;

namespace Version {

    private int compare_version (string a, string b) {
        var pa = a.split("."), pb = b.split(".");
        for(int i = 0; i < int.max(pa.length, pb.length); i++) {
            if(i == pa.length || int.parse(pa[i]) < int.parse(pb[i])) {
                return -1;
            }
            if(i == pb.length || int.parse(pb[i]) < int.parse(pa[i])) {
                return 1;
            }
        }
        return 0;
    }

    public void update_version (string new_version, string data_path) {
        var file = File.new_for_path (data_path + "/version");
        string old_version;
        try {
            var stream = new DataInputStream (file.read ());
            old_version = stream.read_line ();
        } catch (Error e) {
            old_version = "";
        }
        file.replace_contents (new_version.data, null, false, FileCreateFlags.NONE, null);

        if(compare_version(old_version, "0.2.3") == -1) {
            Ui.ConvData.overwrite_all = true;
        }
    }

}
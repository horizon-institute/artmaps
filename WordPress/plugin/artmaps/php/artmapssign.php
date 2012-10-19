<?php
//TODO: This should be requested as an XML-RPC call
error_log("ArtMaps: Deprecation warning\n" . __FILE__);
header("Content-type: application/json", true);
require_once("../../../../wp-config.php");
require_once(ABSPATH . "/wp-admin/includes/plugin.php");
error_log("ArtMaps: Deprecation warning - please use the XML-RPC interface for signing requests");
if(!isset($ArtMapsCore) || !is_plugin_active_for_network("artmaps/artmaps.php"))
    die("The ArtMaps plugin is not active");
if(!is_user_logged_in()) {
    header("HTTP/1.1 403 Forbidden");
    return;
}
?>
<?= json_encode($ArtMapsCore->signData(
        json_decode(file_get_contents("php://input"), true), false)) ?>
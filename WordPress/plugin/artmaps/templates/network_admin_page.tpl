{if $updated}
<div class="updated">
    <p>
        <strong>Settings Updated</strong>
    </p>
</div>
{/if}
<div class="wrap">
    <form method="post" action="">
        <h2>ArtMaps Settings</h2>
        <h3>Core Server URL</h3>
        <p>
            <label for="artmaps_core_server_url">
                <input
                        style="width: 40%"
                        type="text"
                        id="artmaps_core_server_url"
                        name="artmaps_core_server_url"
                        value="{$coreServerUrl}" />
            </label>
        </p>
        <h3>Master Key</h3>
        {if $masterKeyIsSet}
        <h4>For security, the saved key is not displayed</h4>
        {else}
        <h4>No key is currently assigned</h4>
        {/if}
        <textarea 
                name="artmaps_master_key" 
                style="width: 80%; height: 100px;"></textarea>
        <h3>Google Maps API Key</h3>
        <p>
            <label for="artmaps_google_maps_api_key">
                <input
                        style="width: 40%"
                        type="text"
                        id="artmaps_google_maps_api_key"
                        name="artmaps_google_maps_api_key"
                        value="{$mapKey}" />
            </label>
        </p>
        <h3>IP InfoDB API Key</h3>
        <p>
            <label for="artmaps_ipinfodb_api_key">
                <input
                        style="width: 40%"
                        type="text"
                        id="artmaps_ipinfodb_api_key"
                        name="artmaps_ipinfodb_api_key"
                        value="{$ipInfoDbKey}" />
            </label>
        </p>
        <div class="submit">
        <input
                class="button-primary"
                type="submit"
                name="artmaps_network_config_update"
                value="Save Changes" />
        </div>
    </form>
</div>
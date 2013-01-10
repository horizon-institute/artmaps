/* Namespace: ArtMaps */
var ArtMaps = ArtMaps || (function(){
    
    /* Extend google.maps.MVCObject */
    google.maps.MVCObject.prototype.on = function(eventName, handler) {
        return google.maps.event.addListener(this, eventName, handler);
    };
    google.maps.MVCObject.prototype.off = function(listener) {
        google.maps.event.removeListener(listener);
    };

    /* Extend google.maps.Map */
    google.maps.Map.prototype.putObjectMarker = function(reference, marker) {
        if(!this.hasOwnProperty("_objectMarkers_")) this._objectMarkers_ = {};
        this._objectMarkers_[reference] = marker;
    };
    google.maps.Map.prototype.hasObjectMarker = function(reference) {
        if(!this.hasOwnProperty("_objectMarkers_")) this._objectMarkers_ = {};
        return this._objectMarkers_.hasOwnProperty(reference);
    };
    google.maps.Map.prototype.getObjectMarker = function(reference) {
        if(!this.hasOwnProperty("_objectMarkers_")) this._objectMarkers_ = {};
        return this._objectMarkers_.hasOwnProperty(reference)
            ? this._objectMarkers_[reference]
            : null;
    };

    /* Extend MarkerClusterer */
    MarkerClusterer.prototype.on = function(eventName, handler) {
        return google.maps.event.addListener(this, eventName, handler);
    };
    MarkerClusterer.prototype.off = function(listener) {
        google.maps.event.removeListener(listener);
    };

    return {};
}());

ArtMaps.Location = function(l, o, as) {
    this.ID = l.ID;
    this.Source = l.source;
    this.Latitude = ArtMaps.Util.toFloatCoord(l.latitude);
    this.Longitude = ArtMaps.Util.toFloatCoord(l.longitude);
    this.Error = l.error;
    this.ObjectOfInterest = o;
    this.Actions = as;
    this.Confirmations = 0;
    
    // Find the number of confirmations
    var l = as.length;
    for(var i = 0; i < l; i++)
        if(as[i].URI.indexOf("confirmation") == 0)
            this.Confirmations++;
};

ArtMaps.ObjectOfInterest = function(o) {
    this.ID = o.ID;
    this.URI = o.URI;
    this.Locations = [];
    this.Metadata = {};
    this.SuggestionCount = 0;
    
    // Sort actions by location
    var abl = {};
    var re = /^.*LocationID"\s*:\s*(\d+).*$/;
    var l = o.actions.length;
    for(var i = 0; i < l; i++) {
        var a = o.actions[i];
        var lid = a.URI.replace(re, "$1");
        if(!abl[lid]) abl[lid] = new Array();
        var arr = abl[lid];
        arr[arr.length] = a;
    }
    // Sort actions into timestamp order (ascending)
    for(var as in abl)
        abl[as].sort(ArtMaps.Util.actionArraySort);
    // Create location objects
    l = o.locations.length;
    for(var i = 0; i < l; i++) {
        var loc = o.locations[i];
        var as = abl[loc.ID] ? abl[loc.ID] : [];
        this.Locations[this.Locations.length] = new ArtMaps.Location(loc, this, as);
        if(loc.source != "SystemImport") this.SuggestionCount++;            
    }
    // Fetch metadata
    var self = this;
    var mdLoaded = false;
    var mdIsLoading = false;
    var fQueue = new Array();
    var loadMetadata = function() {
        if(mdLoaded || mdIsLoading) return;
        mdIsLoading = true;
        jQuery.getJSON(
                ArtMapsConfig.CoreServerPrefix + "objectsofinterest/" 
                        + o.ID + "/metadata",
                function(data) {
                    self.Metadata = data;
                    mdLoaded = true;
                    jQuery.each(fQueue, function(i, f) {
                       f(data); 
                    });
        });
    };
    
    this.runWhenMetadataLoaded = function(func) {
        window.setTimeout(function() {
            if(mdLoaded) { 
                func(self.Metadata);
                return;
            }
            fQueue.push(func);
            loadMetadata();
        }, 0);
    };
};

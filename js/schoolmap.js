var SCHOOLMAP = {
    default_zoom:12,
    default_center:new google.maps.LatLng( 53.82659674299412, -1.86767578125 ),
    schools_url:"schools",
    school_url:"school",
    schools:[],
    params:{},
    nschools:0,
    place:false,
    result_types:{ 
        "primary":"Key stage 2",
        "secondary":"GCSE",
        "post16":"A Levels" 
    },
    request:false,
    curtags:[ "body", "a", "input", "select", "div" ],
    default_phase:{ colour: "ff00ff", active_colour:"ffaaff" },
    phases:{
        "Primary":{ colour: "ff00ff", active_colour:"ffaaff" },
        "Secondary":{ colour: "00ff00", active_colour:"aaffaa" },
        "Nursery":{ colour: "ffff00", active_colour:"ffffaa" },
        "Middle Deemed Primary":{ colour: "00ffff", active_colour:"aaffff" },
        "Middle Deemed Secondary":{ colour: "ff0000", active_colour:"ffaaaa" },
        "Not applicable":{ colour: "0000ff", active_colour:"aaaaff" },
    },
    handle_zoom:false,
    handle_move:false,
    addressMarker:false
};

SCHOOLMAP.setMapListeners = function() 
{
    SCHOOLMAP.handle_zoom = google.maps.event.addListener( 
        SCHOOLMAP.map, 
        "zoomend", 
        function() { SCHOOLMAP.getSchools(); }
    );
    SCHOOLMAP.handle_move = google.maps.event.addListener( 
        SCHOOLMAP.map, 
        "moveend", 
        function() {
            SCHOOLMAP.getSchools();
        }
    );
};

SCHOOLMAP.removeMapListeners = function() {
    if ( SCHOOLMAP.handle_zoom )
    {
        google.maps.event.removeListener( SCHOOLMAP.handle_zoom );
        SCHOOLMAP.handle_zoom = false;
    }
    if ( SCHOOLMAP.handle_move )
    {
        google.maps.event.removeListener( SCHOOLMAP.handle_move );
        SCHOOLMAP.handle_move = false;
    }
}

SCHOOLMAP.createAddressMarker = function() 
{
    console.log( "createAddressMarker" );
    console.log( SCHOOLMAP.place );
    if ( ! SCHOOLMAP.place ) return;
    var latlng = SCHOOLMAP.place.geometry.location;
    console.log( latlng );
    if ( SCHOOLMAP.addressMarker ) return;
    SCHOOLMAP.addressMarker = new google.maps.Marker( 
        { 
            "position": latlng,
            "draggable": true,
            "icon": { url: "/markers/image.png" },
            "map": SCHOOLMAP.map
        } 
    );
    console.log( SCHOOLMAP.addressMarker );
    google.maps.event.addListener( 
        SCHOOLMAP.addressMarker, 
        "dragend", 
        function( e ) { 
            console.log( e );
            console.log( e.latLng );
            SCHOOLMAP.findAddress( 
                e.latLng.lat() + "," + e.latLng.lng(),
                function( point ) {
                    SCHOOLMAP.resetDistances();
                    SCHOOLMAP.updateSchools();
                }
            );
        }
    );
};

SCHOOLMAP.removeSchoolMarkers = function() 
{
    var listDiv = document.getElementById( "list" );
    SCHOOLMAP.removeChildren( listDiv );
    for ( var i = 0; i < SCHOOLMAP.schools.length; i++ )
    {
        var school = SCHOOLMAP.schools[i];
        school.markers.setMap( null );
    }
};

SCHOOLMAP.findAddress = function( query, callback ) 
{
    SCHOOLMAP.geocoder.geocode( 
        { "address": query }, 
        function ( results, status ) {
            if ( ! google.maps.GeocoderStatus.OK )
            {
                alert("\"" + query + "\" not found");
                return;
            }
            var result = results[0];
            SCHOOLMAP.place = result;
            SCHOOLMAP.createAddressMarker();
            var input = document.getElementById( "address" );
            input.value = SCHOOLMAP.place.formatted_address;
            var span = document.getElementById( "coords" );
            SCHOOLMAP.setText( span, "( lat: " + SCHOOLMAP.place.geometry.location.lat() + ", lng: " + SCHOOLMAP.place.geometry.location.lng() + ")" );
            if ( callback ) callback( SCHOOLMAP.place.geometry.location );
        }
    );
};

SCHOOLMAP.removeChildren = function( parent ) 
{
    try {
        while ( parent.childNodes.length ) parent.removeChild( parent.childNodes[0] );
    }
    catch(e) { console.error( e.message ) }
}

SCHOOLMAP.createLinkTo = function( query_string ) 
{
    var url = document.URL;
    url = url.replace( /\?.*$/, "" );
    var url = url + "?" + query_string;
    var link1 = document.createElement( "A" );
    url = SCHOOLMAP.schools_url + "?" + query_string + "&format=xml";
    link1.href = url;
    SCHOOLMAP.setText( link1, "XML" );
    var link2 = document.createElement( "A" );
    url = SCHOOLMAP.schools_url + "?" + query_string + "&format=georss";
    link2.href = url;
    SCHOOLMAP.setText( link2, "GeoRSS" );
    var link3 = document.createElement( "A" );
    url = SCHOOLMAP.schools_url + "?" + query_string + "&format=kml";
    link3.href = url;
    SCHOOLMAP.setText( link3, "KML" );
    var link4 = document.createElement( "A" );
    url = SCHOOLMAP.schools_url + "?" + query_string + "&format=json";
    link4.href = url;
    SCHOOLMAP.setText( link4, "JSON" );
    linkToDiv = document.getElementById( "linkto" );
    if ( ! linkToDiv ) return;
    SCHOOLMAP.removeChildren( linkToDiv );
    linkToDiv.appendChild( document.createTextNode( "link to this page: " ) );
    linkToDiv.appendChild( link1 );
    linkToDiv.appendChild( document.createTextNode( " | " ) );
    linkToDiv.appendChild( link2 );
    linkToDiv.appendChild( document.createTextNode( " | " ) );
    linkToDiv.appendChild( link3 );
    linkToDiv.appendChild( document.createTextNode( " | " ) );
    linkToDiv.appendChild( link4 );
};

SCHOOLMAP.getJSON = function( url, callback ) 
{
    SCHOOLMAP.setCursor( "wait" );
    if ( SCHOOLMAP.request )
    {
        console.log( "abort " + SCHOOLMAP.request );
        SCHOOLMAP.request.abort();
    }
    SCHOOLMAP.request = SCHOOLMAP.createXMLHttpRequest();
    SCHOOLMAP.request.open( 'GET', url, true );
    SCHOOLMAP.request.onreadystatechange = function() {
        if ( SCHOOLMAP.request.readyState != 4 ) return;
        if ( SCHOOLMAP.request.status == 0 ) return; // aborted request
        SCHOOLMAP.setCursor( "default" );
        if ( SCHOOLMAP.request.status == 200 ) callback( SCHOOLMAP.request );
        else console.error( "GET " + url + " failed: " + SCHOOLMAP.request.status );
    };
    SCHOOLMAP.request.send( null );
}

SCHOOLMAP.get = function( url, callback ) {
    var request = SCHOOLMAP.createXMLHttpRequest();
    request.open( 'GET', url, true );
    request.onreadystatechange = function() {
        if ( request.readyState != 4 ) return;
        if ( request.status == 0 ) return; // aborted request
        SCHOOLMAP.setCursor( "default" );
        if ( request.status == 200 ) callback( request );
        else console.error( "GET " + url + " failed: " + request.status );
    };
    console.log( url );
    request.send( null );
}

SCHOOLMAP.createXMLHttpRequest = function() {
    if ( typeof XMLHttpRequest != "undefined" )
    {
        return new XMLHttpRequest();
    } else if ( typeof ActiveXObject != "undefined" )
    {
        return new ActiveXObject( "Microsoft.XMLHTTP" );
    } else {
        throw new Error( "XMLHttpRequest not supported" );
    }
}

SCHOOLMAP.setCursor = function( state ) {
    for ( var i = 0; i < SCHOOLMAP.curtags.length; i++ )
    {
        var tag = SCHOOLMAP.curtags[i];
        var es = document.getElementsByTagName( tag );
        for ( var j = 0; j < es.length; j++ )
        {
            es[j].style.cursor = state;
        }
    }
}

SCHOOLMAP.getQueryString = function() 
{
    var bounds = SCHOOLMAP.map.getBounds();
    var sw = bounds.getSouthWest();
    var ne = bounds.getNorthEast();
    var query_string = 
        "&minLon=" + escape( sw.lng() ) + 
        "&maxLon=" + escape( ne.lng() ) + 
        "&minLat=" + escape( sw.lat() ) + 
        "&maxLat=" + escape( ne.lat() )
    ;
    var order_by = document.forms[0].order_by;
    if ( order_by ) 
    {
        var order_by_val = order_by.value;
        if ( order_by_val == "distance" ) order_by_val = "";
        query_string = query_string + "&order_by=" + escape( order_by_val );
    }
    var phase = document.forms[0].phase;
    if ( phase ) 
    {
        var phase_val = phase.value;
        if ( phase_val == "all" ) phase_val = "";
        query_string = query_string + "&phase=" + escape( phase_val );
    }
    var type = document.forms[0].type;
    if ( type ) 
    {
        var type_val = type.value;
        if ( type_val == "all" ) type_val = "";
        query_string = query_string + "&type=" + escape( type_val );
    }
    return query_string;
};

SCHOOLMAP.getSchools = function() 
{
    var order_by = document.forms[0].order_by;
    if ( ! order_by ) return;
    var type = document.forms[0].type;
    if ( ! type ) return;
    var query_string = SCHOOLMAP.getQueryString();
    var url = SCHOOLMAP.schools_url + "?" + query_string;
    SCHOOLMAP.createLinkTo( query_string );
    SCHOOLMAP.getJSON( url, SCHOOLMAP.getSchoolsCallback );
};

SCHOOLMAP.typesCallback = function( response ) 
{
    var types = JSON.parse( response.responseText );
    var sel = document.forms[0].type;
    if ( sel )
    {
        var val = sel.value;
        SCHOOLMAP.removeChildren( sel );
        for ( var i = 0; i < types.length; i++ )
        {
            SCHOOLMAP.addOpt( sel, types[i] );
        }
        sel.value = val;
    }
};

SCHOOLMAP.schoolsChanged = function( schools ) 
{
    // check to see if the list of schools has changed ...
    if ( schools.length != SCHOOLMAP.schools.length ) return true;
    try {
        for ( var i = 0;i < schools.length; i++ )
        {
            if ( schools[i].URN != SCHOOLMAP.schools[i].URN ) return true;
        }
        return false;
    } catch( e ) { console.error( e.message ) }
};

SCHOOLMAP.getSchoolsCallback = function( response ) 
{
    var json = JSON.parse( response.responseText );
    if ( SCHOOLMAP.schoolsChanged( json.schools ) )
    {
        SCHOOLMAP.removeSchoolMarkers();
        SCHOOLMAP.active_school = false;
        SCHOOLMAP.nschools = json.nschools;
        SCHOOLMAP.schools = json.schools;
        SCHOOLMAP.updateSchools();
    }
    else
    {
        console.log( "schools not changed" );
    }
};

SCHOOLMAP.updateSchools = function()
{
    var order_by = document.forms[0].order_by.value;
    SCHOOLMAP.calculateAllDistances( 0 );
};

SCHOOLMAP.redrawSchools = function( ) 
{
    try {
        var body = document.getElementsByTagName( "body" );
        body[0].style.cursor = "auto";
        for ( var i = 0; i < SCHOOLMAP.schools.length; i++ )
        {
            var school = SCHOOLMAP.schools[i];
            school.no = i+1;
            if ( ! school.school_type ) school.school_type = "unknown";
            var phase = SCHOOLMAP.phases[school.PhaseOfEducation];
            if ( ! phase )
            {
                phase = SCHOOLMAP.default_phase;
            }
            var colour = phase.colour;
            var symbol = SCHOOLMAP.getSymbol( colour );
            if ( school.marker )
            {
                school.marker.setIcon( symbol );
            }
            else
            {
                SCHOOLMAP.createMarker( school, symbol );
            }
        }
        SCHOOLMAP.updateList( );
    } catch( e ) { console.error( e.message ) }
};

SCHOOLMAP.orderByOnChange = function()
{
    SCHOOLMAP.getSchools();
};

SCHOOLMAP.typeOnChange = function()
{
    SCHOOLMAP.getSchools();
};

SCHOOLMAP.updateList = function( )
{
        var listDiv = document.getElementById( "list" );
        SCHOOLMAP.removeChildren( listDiv );
        if ( SCHOOLMAP.schools.length )
            listDiv.appendChild( SCHOOLMAP.createListTable() );
};

SCHOOLMAP.activateSchool = function( school )
{
    SCHOOLMAP.changeLinksColour( school, "ff4444" );
    var phase = SCHOOLMAP.phases[school.PhaseOfEducation];
    if ( ! phase )
    {
        phase = SCHOOLMAP.default_phase;
    }
    SCHOOLMAP.changeMarkerColour( school, phase.active_colour )
    if ( SCHOOLMAP.active_school ) SCHOOLMAP.deActivateSchool( SCHOOLMAP.active_school );
    SCHOOLMAP.active_school = school;
    window.status = school.name;
}

SCHOOLMAP.deActivateSchool = function( school ) 
{
    if ( ! school ) return;
    SCHOOLMAP.changeLinksColour( school, "4444ff" );
    var phase = SCHOOLMAP.phases[school.PhaseOfEducation];
    if ( ! phase )
    {
        phase = SCHOOLMAP.default_phase;
    }
    SCHOOLMAP.changeMarkerColour( school, phase.colour );
    SCHOOLMAP.active_school = false;
}

SCHOOLMAP.setParams = function() 
{
    for ( var param in SCHOOLMAP.params )
    {
        SCHOOLMAP.setParam( param );
    }
    if ( SCHOOLMAP.params.centerLng && SCHOOLMAP.params.centerLat )
    {
        SCHOOLMAP.params.center = new google.maps.LatLng( SCHOOLMAP.params.centerLat, SCHOOLMAP.params.centerLng );
    }
    if (
        ! SCHOOLMAP.params.zoom &&
        SCHOOLMAP.params.minLon &&
        SCHOOLMAP.params.minLat &&
        SCHOOLMAP.params.maxLon &&
        SCHOOLMAP.params.maxLat
    )
    {
        var sw = new google.maps.LatLng( SCHOOLMAP.params.minLon, SCHOOLMAP.params.minLat );
        var ne = new google.maps.LatLng( SCHOOLMAP.params.maxLon, SCHOOLMAP.params.maxLat );
        var bounds = new google.maps.LatLngBounds( sw, ne );
        SCHOOLMAP.params.zoom = SCHOOLMAP.map.getBoundsZoomLevel( bounds );
    }
};

SCHOOLMAP.setParam = function( param ) 
{
    if ( SCHOOLMAP.params[param] == "undefined" ) return;
    if ( typeof( SCHOOLMAP.params[param] ) == "undefined" ) return;
    for ( var i = 0; i < document.forms.length; i++ )
    {
        var input = document.forms[i][param];
        if ( input )
        {
            input.value = SCHOOLMAP.params[param];
        }
    }
};

SCHOOLMAP.sortByDistance = function( a, b ) 
{
    return a.meters - b.meters;
};

SCHOOLMAP.resetDistances = function()
{
    for ( var i = 0; i < SCHOOLMAP.schools.length; i++ )
    {
        SCHOOLMAP.schools[i].meters = "";
    }
};

SCHOOLMAP.calculateAllDistances = function( index )
{
    console.log( "SCHOOLMAP.calculateAllDistances: " + index );
    if ( index === SCHOOLMAP.schools.length )
    {
        var order_by = document.forms[0].order_by.value;
        if ( order_by == "distance" )
        {
            SCHOOLMAP.schools = SCHOOLMAP.schools.sort( SCHOOLMAP.sortByDistance );
        }
        console.log( "SCHOOLMAP.redrawSchools" );
        SCHOOLMAP.redrawSchools();
        return;
    }
    var school = SCHOOLMAP.schools[index];
    SCHOOLMAP.calculateDistance( school, function() { SCHOOLMAP.calculateAllDistances( index+1 ) } );
}

SCHOOLMAP.setText = function( e, t ) 
{
    SCHOOLMAP.removeChildren( e );
    e.appendChild( document.createTextNode( t ) );
};

SCHOOLMAP.convertMeters = function( m ) 
{
    if ( m < 1000 ) return m + " m";
    var km = m / 1000;
    return km + " km";
}

SCHOOLMAP.calculateDistance = function( school, callback ) 
{
    if ( ! SCHOOLMAP.place ) return;
    var from = school.lat + "," + school.lon;
    var point = SCHOOLMAP.place.geometry.location;
    var to = point.lat() + "," + point.lng();
    school.directions_text = "from " + from + " to " + to;
    console.log( "calculate distance" );
    var req = {
        "origin": from,
        "destination": to,
        "travelMode": google.maps.TravelMode.WALKING,
        "unitSystem": google.maps.UnitSystem.METRIC
    };
    SCHOOLMAP.gdir.route( 
        req,
        function( result, status ) {
            var meters = "";
            console.log( result );
            if ( status == google.maps.DirectionsStatus.OK ) 
            {
                if ( result.routes && result.routes[0] )
                {
                    var route = result.routes[0];
                    for ( var i = 0; i < route.legs.length; i++ )
                    {
                        var leg = route.legs[0];
                        console.log( leg );
                        console.log( leg.distance );
                        meters = meters + leg.distance.value;
                    }
                    console.log( meters );
                }
            }
            else
            {
                console.error( "directions failed" );
            }
            school.meters = meters;
            if ( school.distance_td ) 
            {
                SCHOOLMAP.removeChildren( school.distance_td );
                var text = SCHOOLMAP.convertMeters( school.meters );
                school.distance_td.appendChild( document.createTextNode( text ) );
            }
            if ( callback ) callback();
        }
    );
};

SCHOOLMAP.createInfoWindow = function( school )
{
    var div = document.createElement( "DIV" );
    div.className = "infoWindow";
    var h2 = document.createElement( "H2" );
    h2.appendChild( document.createTextNode( school.EstablishmentName ) );
    div.appendChild( h2 );
    var p = document.createElement( "P" );
    var address = school.address.split( "," );
    for ( var i = 0; i < address.length; i++ )
    {
        p.appendChild( document.createTextNode( address[i] ) );
        p.appendChild( document.createElement( "BR" ) );
    }
    div.appendChild( p );
    if ( school.HeadLastName )
    {
        var head = school.HeadTitle + " " + school.HeadFirstName + " " + school.HeadLastName;
        p = document.createElement( "P" );
        p.appendChild( 
            document.createTextNode( "Head: " + head )
        );
        if ( school.HeadHonour )
        {
            p.appendChild( document.createElement( "BR" ) );
            p.appendChild( document.createTextNode( school.HeadHonour ) );
        }
        div.appendChild( p );

    }
    return div;
};

SCHOOLMAP.createMarker = function( school, symbol ) {
    try {
        var point = new google.maps.LatLng( school.lat, school.lon );
        school.marker = new google.maps.Marker( { "position": point, "map": SCHOOLMAP.map, "icon": symbol } );
        google.maps.event.addListener( school.marker, "mouseout", function() { SCHOOLMAP.deActivateSchool( school ) } );
        google.maps.event.addListener( school.marker, "mouseover", function() { SCHOOLMAP.activateSchool( school ) } );
        google.maps.event.addListener( 
            school.marker, 
            "infowindowclose", 
            function() {
                if ( SCHOOLMAP.current_center )
                {
                    SCHOOLMAP.map.setCenter( SCHOOLMAP.current_center );
                }
                SCHOOLMAP.setMapListeners();
            }
        );
        google.maps.event.addListener( 
            school.marker, 
            "infowindowopen", 
            function() {
                SCHOOLMAP.removeMapListeners();
            }
        );
        google.maps.event.addListener( 
            school.marker, 
            "click", 
            function() {
                if ( ! SCHOOLMAP.current_center ) SCHOOLMAP.current_center = SCHOOLMAP.map.getCenter();
            } 
        );
        // var div = SCHOOLMAP.createInfoWindow( school );
        // school.marker.bindInfoWindow( div );
    }
    catch(e) { console.error( e.message ) }
}

SCHOOLMAP.initTableHead = function( tr, result_types ) 
{
    var ths = new Array();
    SCHOOLMAP.createHeadCell( tr, "no" );
    SCHOOLMAP.createHeadCell( tr, "name", "Name of school", 1 );
    SCHOOLMAP.createHeadCell( tr, "phase", "School stage" );
    SCHOOLMAP.createHeadCell( tr, "type", "Type of school" );
    SCHOOLMAP.createHeadCell( tr, "ofsted", "Ofsted overall effectiveness" );
    for ( var i = 0; i < result_types.length; i++ )
    {
        var result_type = result_types[i];
        var description = SCHOOLMAP.result_types[result_type];
        SCHOOLMAP.createHeadCell( tr, description, "average score" );
    }
    if ( SCHOOLMAP.place )
    {
        SCHOOLMAP.createHeadCell( tr, "distance", "Distance from " + SCHOOLMAP.place.formatted_address );
    }
};

SCHOOLMAP.getQueryVariables = function() {
    var query = window.location.search.substring( 1 );
    var vars = query.split( "&" );
    for ( var i = 0; i < vars.length; i++ ) 
    {
        var pair = vars[i].split( "=" );
        var key = unescape( pair[0] );
        var val = unescape( pair[1] );
        val = val.replace( /\+/g, " " );
        SCHOOLMAP.params[key] = val;
    } 
}

SCHOOLMAP.ignoreConsoleErrors = function() {
    if ( ! window.console )
    {
        window.console = {
            log:function() {},
            error:function() {}
        };
    }
}

SCHOOLMAP.initMap = function() 
{
    // $('input#address').autoResize();
    SCHOOLMAP.ignoreConsoleErrors();
    SCHOOLMAP.getQueryVariables();
    SCHOOLMAP.setParams();
    var mapOptions = { 
        googleBarOptions : { 
            style : "new",
            adsOptions: {
                client: "6816728437",
                channel: "AdSense for Search channel",
                adsafe: "high",
                language: "en"
            }
        }
    };
    var map_div = document.getElementById( "map", mapOptions );
    SCHOOLMAP.map = new google.maps.Map( map_div );
    // SCHOOLMAP.map.setUIToDefault();
    // SCHOOLMAP.map.enableGoogleBar();
    // SCHOOLMAP.map.disableScrollWheelZoom();

    var center = SCHOOLMAP.params.center || SCHOOLMAP.default_center;
    var zoom = parseInt( SCHOOLMAP.params.zoom ) || SCHOOLMAP.default_zoom;
    SCHOOLMAP.map.setCenter( center, zoom );
    SCHOOLMAP.gdir = new google.maps.DirectionsService();
    SCHOOLMAP.geocoder = new google.maps.Geocoder();
    // SCHOOLMAP.geocoder.setBaseCountryCode( "uk" );
    google.maps.event.addListener( 
        SCHOOLMAP.map, 
        "moveend", 
        function() {
            var center = SCHOOLMAP.map.getCenter();
            var centerLat = document.getElementById( "centerLat" );
            centerLat.value = center.lat();
            var centerLng = document.getElementById( "centerLng" );
            centerLng.value = center.lng();
        }
    );
    google.maps.event.addListener( 
        SCHOOLMAP.map, 
        "zoomend", 
        function() {
            var zoom = SCHOOLMAP.map.getZoom();
            var zoomInput = document.getElementById( "zoom" );
            zoomInput.value = zoom;
        }
    );
    SCHOOLMAP.setMapListeners();
    if ( SCHOOLMAP.params.address )
    {
        SCHOOLMAP.findAddress( 
            SCHOOLMAP.params.address, 
            function( point ) {
                SCHOOLMAP.removeMapListeners();
                SCHOOLMAP.map.setCenter( point );
                SCHOOLMAP.map.setZoom( zoom );
                var query_string = SCHOOLMAP.getQueryString();
                var types_url = SCHOOLMAP.schools_url + "?" + query_string + "&types";
                // console.log( types_url );
                SCHOOLMAP.get( types_url, SCHOOLMAP.typesCallback );
                SCHOOLMAP.setMapListeners();
                SCHOOLMAP.getSchools();
            }
        );
    }
    else
    {
        SCHOOLMAP.map.setCenter( center, zoom );
    }
};


SCHOOLMAP.createListTd = function( opts ) {
    var td = document.createElement( "TD" );
    if ( opts.url )
    {
        var a = document.createElement( "A" );
        a.target = "_blank";
        a.onclick = function() { window.open( opts.url, "school", "status,scrollbars,resizable,width=800,height=600" ); return false; };
        a.href = opts.url;
        var school = opts.school;
        if ( ! school.links ) school.links = new Array();
        school.links.push( a );
        var text = "-";
        if ( opts.text && opts.text != "null" ) text = opts.text;
        a.appendChild( document.createTextNode( text ) );
        td.appendChild( a );
        a.onmouseover = function() {
            SCHOOLMAP.activateSchool( school );
        };
        a.onmouseout = function() {
            SCHOOLMAP.deActivateSchool( school );
        };
    }
    else
    {
        td.appendChild( document.createTextNode( opts.text ) );
    }
    td.style.verticalAlign = "top";
    if ( opts.nowrap ) td.style.whiteSpace = "nowrap";
    return td;
}

SCHOOLMAP.getResultTypes = function()
{
    var result_types_hash = {};
    for ( var i = 0; i < SCHOOLMAP.schools.length; i++ )
    {
        var school = SCHOOLMAP.schools[i];
        for ( var result_type in SCHOOLMAP.result_types )
        {
            var ave = "average_" + result_type;
            if ( school[ave] && school[ave] != 0 )
            {
                result_types_hash[result_type] = true;
            }
        }
    }
    var result_types_array = [];
    var sel = document.forms[0].order_by;
    var val = sel.value;
    SCHOOLMAP.removeChildren( sel );
    SCHOOLMAP.addOpt( sel, { val: "", str: "-" } );
    SCHOOLMAP.addOpt( sel, { val: "distance", str: "Distance" } );
    for ( var result_type in result_types_hash )
    {
        result_types_array.push( result_type );
        var description = SCHOOLMAP.result_types[result_type];
        SCHOOLMAP.addOpt( sel, { val: result_type, str: description } );
    }
    sel.value = val;
    return result_types_array;
};

SCHOOLMAP.createListRow = function( no, school, result_types ) 
{
    var tr = document.createElement( "TR" );
    var url = false;
    if ( school.dcsf_id && typeof school.dcsf_id != "undefined" )
    {
        url = SCHOOLMAP.school_url + "?table=dcsf&id=" + school.dcsf_id;
    }
    tr.appendChild( SCHOOLMAP.createListTd( { "text":no+1, "url":url, "school":school } ) );
    tr.appendChild( SCHOOLMAP.createListTd( { "text":school.name, "url":url, "school":school } ) );
    tr.appendChild( SCHOOLMAP.createListTd( { "text":school.PhaseOfEducation, "url":url, "school":school } ) );
    tr.appendChild( SCHOOLMAP.createListTd( { "text":school.school_type, "url":url, "school":school } ) );
    tr.appendChild( SCHOOLMAP.createListTd( { "text":school.OfstedStatus, "url":url, "school":school } ) );
    for ( var i = 0; i <  result_types.length; i++ )
    {
        var result_type = result_types[i];
        var ave = "average_" + result_type;
        if ( school[ave] && school[ave] != 0 )
        {
            var val = school[ave];
            var url = SCHOOLMAP.school_url + "?table=dcsf&id=" + school.dcsf_id;
            var td = SCHOOLMAP.createListTd( { "text":val, "url":url, "school":school } );
        }
        else
        {
            var td = SCHOOLMAP.createListTd( { "text":"-" } );
        }
        tr.appendChild( td );
    }
    if ( SCHOOLMAP.place )
    {
        var text = "-";
        if ( school.meters ) text = SCHOOLMAP.convertMeters( school.meters );
        school.distance_td = SCHOOLMAP.createListTd( { "text":text } );
        tr.appendChild( school.distance_td );
    }
    return tr;
}

SCHOOLMAP.createHeadCell = function( tr, name, title ) 
{
    var th = document.createElement( "TH" );
    th.style.verticalAlign = "top";
    tr.appendChild( th );
    var a = document.createElement( "A" );
    th.appendChild( a );
    th.appendChild( document.createElement( "BR" ) );
    a.name = name;
    a.title = title || name;
    a.style.color = "black";
    a.style.textDecoration = "none";
    a.href = "";
    a.onclick = function() { return false; };
    SCHOOLMAP.setText( a, name );
};

SCHOOLMAP.createListTable = function() 
{
    var table = document.createElement( "TABLE" );
    var tbody = document.createElement( "TBODY" );
    table.appendChild( tbody );
    var tr = document.createElement( "TR" );
    tbody.appendChild( tr );
    result_types = SCHOOLMAP.getResultTypes();
    SCHOOLMAP.initTableHead( tr, result_types );
    tbody.appendChild( tr );
    for ( var i = 0; i < SCHOOLMAP.schools.length; i++ )
    {
        var school = SCHOOLMAP.schools[i];
        var tr = SCHOOLMAP.createListRow( i, school, result_types );
        tbody.appendChild( tr );
    }
    var ncells = tr.childNodes.length;
    if ( SCHOOLMAP.place )
    {
        var tr = document.createElement( "TR" );
        tbody.appendChild( tr );
        for ( var i = 0; i < ncells-1; i++ )
        {
            var td = document.createElement( "TD" );
            tr.appendChild( td );
        }
    }
    return table;
};

SCHOOLMAP.getSymbol = function( colour ) 
{
    return {
        path: google.maps.SymbolPath.CIRCLE,
        scale: 10,
        fillOpacity: 10,
        strokeWeight: 1,
        fillColor: colour
    };
}

SCHOOLMAP.changeMarkerColour = function( school, colour ) 
{
    var marker = school.marker;
    var symbol = SCHOOLMAP.getSymbol( colour );
    marker.setIcon( symbol );
};

SCHOOLMAP.changeLinksColour = function( school, color ) 
{
    if ( ! school ) return;
    var links = school.links;
    if ( ! links ) 
    {
        console.error( "no links for " + school.name );
        return;
    }
    for ( var i = 0; i < links.length; i++ )
    {
        link = links[i];
        link.style.color = "#" + color;
    }
};

SCHOOLMAP.addOpt = function( sel, opts ) 
{
    var opt = new Option( opts.str, opts.val );
    if ( opts.isSel ) opt.selected = opts.isSel;
    sel.options[sel.options.length] = opt;
    return opt;
};

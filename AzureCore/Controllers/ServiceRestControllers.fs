﻿#light

namespace ArtMaps.Controllers

open ArtMaps.Persistence.Entities
open Microsoft.ApplicationServer.Caching
open Microsoft.SqlServer.Types
open System.Data.Linq
open System.Linq
open System.Text
open System.Web.Http
open System.Web.Http.ModelBinding

module Conv = ArtMaps.Controllers.Types.Conversions
module CTX = ArtMaps.Context
module E = Errors
module Log = ArtMaps.Utilities.Log
module WU = ArtMaps.Utilities.Web

[<WU.ValidContextFilter()>]
type ObjectsOfInterestController() =
    inherit ApiController()

    [<HttpGet>]
    [<ActionName("Search")>] 
    member this.Search
            ([<ModelBinder(typeof<WU.ContextBinderProvider>)>]context : CTX.t,
                [<FromUri>]qp : Types.QueryParameters) =

        let cname = sprintf "%s_%i_%i_%i_%i" 
                        context.name
                        qp.boundingBox.northEast.latitude
                        qp.boundingBox.northEast.longitude
                        qp.boundingBox.southWest.latitude
                        qp.boundingBox.southWest.longitude

        let n = fun i -> new System.Nullable<float>(Conv.ToFloatCoord i)
        context.dataContext.SelectObjectsWithinBounds(
                n qp.boundingBox.northEast.latitude,
                n qp.boundingBox.southWest.latitude,
                n qp.boundingBox.northEast.longitude,
                n qp.boundingBox.southWest.longitude,
                new System.Nullable<int64>(context.ID)) |> Seq.map Conv.InBoundsResultToObjectRecord

    [<HttpOptions>]
    [<ActionName("Default")>]
    [<WU.CacheHeaderFilter(31536000L)>] // Expiry time set to a year
    member this.Options() = ()

    [<HttpGet>]
    [<ActionName("Default")>]
    member this.Get
            ([<ModelBinder(typeof<WU.ContextBinderProvider>)>]context : CTX.t) : obj=
        raise (E.NotFound(E.NotFoundMinorCode.Unspecified))

    [<HttpGet>]
    [<ActionName("Default")>]
    member this.Get
            ([<ModelBinder(typeof<WU.ContextBinderProvider>)>]context : CTX.t,
                ID : int64) =
        let o = context.dataContext.ObjectOfInterests.SingleOrDefault((fun (o : ObjectOfInterest) -> o.ID = ID))
        if o = null then 
            raise (E.NotFound(E.NotFoundMinorCode.Unspecified))
        o |> Conv.ObjectToObjectRecord

    [<HttpPost>]
    [<ActionName("Default")>]
    member this.Post
            ([<ModelBinder(typeof<WU.ContextBinderProvider>)>]context : CTX.t,
                interest : Types.ObjectOfInterest,
                [<ModelBinder(typeof<WU.EncodingBinderProvider>)>]enc : Encoding) =
        try
            let data = enc.GetBytes(sprintf "%s%i%s%s"
                        interest.URI
                        interest.timestamp
                        interest.userLevel
                        interest.username)
            if context.verifySignature data (interest.signature :> obj) |> not then
                raise (E.Forbidden(E.ForbiddenMinorCode.InvalidSignature))
        with 
            | :? HttpResponseException as e ->
                raise e
            | _ ->
                raise (E.Forbidden(E.ForbiddenMinorCode.InvalidSignature))
              
        if System.DateTime.UtcNow > ((Conv.ToDateTime interest.timestamp) + System.TimeSpan.FromMinutes(float 5)) then
            raise (E.Forbidden(E.ForbiddenMinorCode.Expired))

        let o = new ObjectOfInterest()
        o.ID <- context.getNextID(o :> obj)
        o.URI <- interest.URI
        context.dataContext.ObjectOfInterests.InsertOnSubmit(o)
        context.dataContext.SubmitChanges()
        o |> Conv.ObjectToObjectRecord


[<WU.ValidContextFilter()>]
type ActionsController() =
    inherit ApiController()

    [<HttpOptions>]
    [<ActionName("Default")>]
    [<WU.CacheHeaderFilter(31536000L)>] // Expiry time set to a year
    member this.Options() = ()

    [<HttpGet>]
    [<ActionName("Default")>]
    member this.GetAll
            ([<ModelBinder(typeof<WU.ContextBinderProvider>)>]context : CTX.t,
                oID : int64) =
        let o = context.dataContext.ObjectOfInterests.SingleOrDefault((fun (o : ObjectOfInterest) -> o.ID = oID))
        if o = null then 
            raise (E.NotFound(E.NotFoundMinorCode.Unspecified))
        o.Actions |> Seq.map Conv.ActionToActionRecord |> Seq.toList

    [<HttpGet>]
    [<ActionName("Default")>]
    [<WU.CacheHeaderFilter(31536000L)>] // Expiry time set to a year
    member this.Get
            ([<ModelBinder(typeof<WU.ContextBinderProvider>)>]context : CTX.t,
                oID : int64,
                ID : int64) =
        let o = context.dataContext.ObjectOfInterests.SingleOrDefault((fun (o : ObjectOfInterest) -> o.ID = oID))
        if o = null then 
            raise (E.NotFound(E.NotFoundMinorCode.Unspecified))
        let a = o.Actions.SingleOrDefault(fun (a : Action) -> a.ID = ID)
        if a = null then
            raise (E.NotFound(E.NotFoundMinorCode.Unspecified))
        a |> Conv.ActionToActionRecord

    [<HttpPost>]
    [<ActionName("Default")>]
    member this.Post
            ([<ModelBinder(typeof<WU.ContextBinderProvider>)>]context : CTX.t,
                oID : int64,
                action : Types.Action,
                [<ModelBinder(typeof<WU.EncodingBinderProvider>)>]enc : Encoding) =
        let o = context.dataContext.ObjectOfInterests.SingleOrDefault((fun (o : ObjectOfInterest) -> o.ID = oID))
        if o = null then 
            raise (E.NotFound(E.NotFoundMinorCode.Unspecified))
        
        try
            let data = enc.GetBytes(sprintf "%s%i%s%s" action.URI action.timestamp action.userLevel action.username)
            if context.verifySignature data (action.signature :> obj) |> not then
                raise (E.Forbidden(E.ForbiddenMinorCode.InvalidSignature))
        with 
            | :? HttpResponseException as e ->
                raise e
            | _ ->
                raise (E.Forbidden(E.ForbiddenMinorCode.InvalidSignature))
              
        if System.DateTime.UtcNow > ((Conv.ToDateTime action.timestamp) + System.TimeSpan.FromMinutes(float 5)) then
            raise (E.Forbidden(E.ForbiddenMinorCode.Expired))

        let userURI = sprintf "%s://%s" context.name action.username
        let u = match context.dataContext.Users.SingleOrDefault(fun (u : User) -> u.URI = userURI) with
                    | null -> 
                        let u = new User()
                        u.ID <- context.getNextID(u :> obj)
                        u.URI <- userURI
                        context.dataContext.Users.InsertOnSubmit(u)
                        context.dataContext.SubmitChanges()
                        u
                    | _ as u -> u
        let a = new Action()
        a.ID <- context.getNextID(a :> obj)
        a.ObjectOfInterest <- o
        a.User <- u
        a.URI <- action.URI
        a.DateTime <- System.DateTime.UtcNow
        context.dataContext.Actions.InsertOnSubmit(a)
        context.dataContext.SubmitChanges()
        a |> Conv.ActionToActionRecord


[<WU.ValidContextFilter()>]
type LocationsController() =
    inherit ApiController()

    [<HttpOptions>]
    [<ActionName("Default")>]
    [<WU.CacheHeaderFilter(31536000L)>] // Expiry time set to a year
    member this.Options() = ()

    [<HttpGet>]
    [<ActionName("Default")>]
    member this.GetAll
            ([<ModelBinder(typeof<WU.ContextBinderProvider>)>]context : CTX.t,
                oID : int64) =
        let o = context.dataContext.ObjectOfInterests.SingleOrDefault((fun (o : ObjectOfInterest) -> o.ID = oID))
        if o = null then 
            raise (E.NotFound(E.NotFoundMinorCode.Unspecified))
        o.Locations |> Seq.map Conv.LocationToLocationRecord |> Seq.toList    

    [<HttpGet>]
    [<ActionName("Default")>]
    [<WU.CacheHeaderFilter(31536000L)>] // Expiry time set to a year
    member this.Get
            ([<ModelBinder(typeof<WU.ContextBinderProvider>)>]context : CTX.t,
                oID : int64,
                ID : int64) =
        let o = context.dataContext.ObjectOfInterests.SingleOrDefault((fun (o : ObjectOfInterest) -> o.ID = oID))
        if o = null then 
            raise (E.NotFound(E.NotFoundMinorCode.Unspecified))
        let l = o.Locations.SingleOrDefault(fun (l : Location) -> l.ID = ID)
        if l = null then
            raise (E.NotFound(E.NotFoundMinorCode.Unspecified))
        l |> Conv.LocationToLocationRecord

    [<HttpPost>]
    [<ActionName("Default")>]
    member this.Post
            ([<ModelBinder(typeof<WU.ContextBinderProvider>)>]context : CTX.t,
                oID : int64,
                location : Types.PointLocation,
                [<ModelBinder(typeof<WU.EncodingBinderProvider>)>]enc : Encoding) =
        let o = context.dataContext.ObjectOfInterests.SingleOrDefault((fun (o : ObjectOfInterest) -> o.ID = oID))
        if o = null then 
            raise (E.NotFound(E.NotFoundMinorCode.Unspecified))
        
        try
            let data = enc.GetBytes(sprintf "%i%i%i%i%s%s"
                        location.error
                        location.latitude
                        location.longitude
                        location.timestamp
                        location.userLevel
                        location.username)
            if context.verifySignature data (location.signature :> obj) |> not then
                raise (E.Forbidden(E.ForbiddenMinorCode.InvalidSignature))
        with 
            | :? HttpResponseException as e ->
                Log.Warning "Signature Verification Warning: Invalid signature"
                raise e
            | _ as e ->
                sprintf "Signature Verification Failed: %s\n%s" e.Message e.StackTrace |> Log.Warning
                raise (E.Forbidden(E.ForbiddenMinorCode.InvalidSignature))

        if System.DateTime.UtcNow > ((Conv.ToDateTime location.timestamp) + System.TimeSpan.FromMinutes(float 5)) then
            raise (E.Forbidden(E.ForbiddenMinorCode.Expired))

        let userURI = sprintf "%s://%s" context.name location.username
        let u = match context.dataContext.Users.SingleOrDefault(fun (u : User) -> u.URI = userURI) with
                    | null -> 
                        let u = new User()
                        u.ID <- context.getNextID(u :> obj)
                        u.URI <- userURI
                        context.dataContext.Users.InsertOnSubmit(u)
                        context.dataContext.SubmitChanges()
                        u
                    | _ as u -> u
        
        let p = new LocationPoint()
        p.ID <- context.getNextID(p :> obj)
        p.Error <- location.error
        p.Center <- SqlGeography.Point(Conv.ToFloatCoord location.latitude, Conv.ToFloatCoord location.longitude, Conv.SRID)
        context.dataContext.LocationPoints.InsertOnSubmit(p)
        let l = new Location()
        l.ID <- context.getNextID(l :> obj)
        l.LocationSource <- LocationSource.User
        l.ObjectOfInterest <- o
        l.LocationPoints.Add(p)
        context.dataContext.Locations.InsertOnSubmit(l)
        context.dataContext.SubmitChanges()
        l |> Conv.LocationToLocationRecord |> Option.get


[<WU.ValidContextFilter()>]
type MetadataController() =
    inherit ApiController()

    static let cache = new DataCache("metadata")

    [<HttpOptions>]
    [<ActionName("Default")>]
    [<WU.CacheHeaderFilter(31536000L)>] // Expiry time set to a year
    member this.Options() = ()

    [<HttpGet>]
    [<ActionName("Default")>]
    [<WU.CacheHeaderFilter(31536000L)>] // Expiry time set to a year
    member this.Get
            ([<ModelBinder(typeof<WU.ContextBinderProvider>)>]context : CTX.t,
                oID : int64) =
        
        let cname = sprintf "%s_%i" context.name oID
        let m = cache.Get(cname)
        match m with
            | null ->
                let o = context.dataContext.ObjectOfInterests.SingleOrDefault((fun (o : ObjectOfInterest) -> o.ID = oID))
                if o = null then 
                    raise (E.NotFound(E.NotFoundMinorCode.Unspecified))
                let filters = ArtMaps.Controllers.Metadata.GetFilters(o.URI)
                let m = filters.[0](o.URI)
                cache.Add(cname, m) |> ignore
                m :> obj
            | _ -> m

async = require 'async'
mongoose = require 'mongoose'
Handler = require '../commons/Handler'
Classroom = require './../models/Classroom'
User = require '../models/User'
sendwithus = require '../sendwithus'
utils = require '../lib/utils'
log = require 'winston'
UserHandler = require './user_handler'

ClassroomHandler = class ClassroomHandler extends Handler
  modelClass: Classroom
  jsonSchema: require '../../app/schemas/models/classroom.schema'
  allowedMethods: ['GET', 'PUT', 'DELETE']

  hasAccess: (req) ->
    return false unless req.user
    return true if req.method is 'GET'
    req.method in @allowedMethods or req.user?.isAdmin()

  hasAccessToDocument: (req, document, method=null) ->
    return false unless document?
    return true if req.user?.isAdmin()
    return true if document.get('ownerID')?.equals req.user?._id
    isGet = (method or req.method).toLowerCase() is 'get'
    isMember = _.any(document.get('members') or [], (memberID) -> memberID.equals(req.user.get('_id')))
    return true if isGet and isMember
    false

  formatEntity: (req, doc) ->
    if req.user?.isAdmin() or req.user?.get('_id').equals(doc.get('ownerID'))
      return doc.toObject()
    return _.omit(doc.toObject(), 'code', 'codeCamel')

  get: (req, res) ->
    if memberID = req.query.memberID
      unless req.user and (req.user.isAdmin() or memberID is req.user.id)
        log.debug "classroom_handler.get: memberID (#{memberID}) must be yourself (#{req.user?.id})"
        return @sendForbiddenError(res)
      return @sendBadInputError(res, 'Bad memberID') unless utils.isID memberID
      Classroom.find {members: mongoose.Types.ObjectId(memberID)}, (err, classrooms) =>
        return @sendDatabaseError(res, err) if err
        return @sendSuccess(res, (@formatEntity(req, classroom) for classroom in classrooms))
    else
      super(arguments...)


module.exports = new ClassroomHandler()

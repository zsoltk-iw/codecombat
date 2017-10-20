async = require 'async'
Handler = require '../commons/Handler'
Campaign = require '../models/Campaign'
Classroom = require '../models/Classroom'
Course = require '../models/Course'
CourseInstance = require './../models/CourseInstance'
LevelSession = require '../models/LevelSession'
LevelSessionHandler = require './level_session_handler'
Prepaid = require '../models/Prepaid'
PrepaidHandler = require './prepaid_handler'
User = require '../models/User'
UserHandler = require './user_handler'
utils = require '../../app/core/utils'
{objectIdFromTimestamp} = require '../lib/utils'
sendwithus = require '../sendwithus'
mongoose = require 'mongoose'

CourseInstanceHandler = class CourseInstanceHandler extends Handler
  modelClass: CourseInstance
  jsonSchema: require '../../app/schemas/models/course_instance.schema'
  allowedMethods: ['GET', 'POST', 'PUT', 'DELETE']

  logError: (user, msg) ->
    console.warn "Course instance error: #{user.get('slug')} (#{user._id}): '#{msg}'"

  hasAccess: (req) ->
    req.method in @allowedMethods or req.user?.isAdmin()

  hasAccessToDocument: (req, document, method=null) ->
    return true if document?.get('ownerID')?.equals(req.user?.get('_id'))
    return true if req.method is 'GET' and _.find document?.get('members'), (a) -> a.equals(req.user?.get('_id'))
    req.user?.isAdmin()

module.exports = new CourseInstanceHandler()

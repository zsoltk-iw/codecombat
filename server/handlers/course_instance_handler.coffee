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

  post: (req, res) ->
    return @sendUnauthorizedError(res) if not req.user?
    return @sendBadInputError(res, 'No classroomID') unless req.body.classroomID
    return @sendBadInputError(res, 'No courseID') unless req.body.courseID
    Classroom.findById req.body.classroomID, (err, classroom) =>
      return @sendDatabaseError(res, err) if err
      return @sendNotFoundError(res, 'Classroom not found') unless classroom
      return @sendForbiddenError(res) unless classroom.get('ownerID').equals(req.user.get('_id'))
      Course.findById req.body.courseID, (err, course) =>
        return @sendDatabaseError(res, err) if err
        return @sendNotFoundError(res, 'Course not found') unless course
        q = {
          courseID: mongoose.Types.ObjectId(req.body.courseID)
          classroomID: mongoose.Types.ObjectId(req.body.classroomID)
        }
        CourseInstance.findOne(q).exec (err, doc) =>
          return @sendDatabaseError(res, err) if err
          return @sendSuccess(res, @formatEntity(req, doc)) if doc
          super(req, res)

  makeNewInstance: (req) ->
    doc = new CourseInstance({
      members: []
      ownerID: req.user.get('_id')
    })
    doc.set('aceConfig', {}) # constructor will ignore empty objects
    return doc

  get: (req, res) ->
    if classroomID = req.query.classroomID
      return @sendForbiddenError(res) unless req.user
      return @sendBadInputError(res, 'Bad memberID') unless utils.isID classroomID
      Classroom.findById classroomID, (err, classroom) =>
        return @sendDatabaseError(res, err) if err
        return @sendNotFoundError(res) unless classroom
        return @sendForbiddenError(res) unless classroom.isMember(req.user._id) or classroom.isOwner(req.user._id) or req.user.isAdmin()
        CourseInstance.find {classroomID: mongoose.Types.ObjectId(classroomID)}, (err, courseInstances) =>
          return @sendDatabaseError(res, err) if err
          return @sendSuccess(res, (@formatEntity(req, courseInstance) for courseInstance in courseInstances))
    else
      super(arguments...)

module.exports = new CourseInstanceHandler()

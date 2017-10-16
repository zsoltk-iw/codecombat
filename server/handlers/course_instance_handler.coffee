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

  getByRelationship: (req, res, args...) ->
    relationship = args[1]
    return @findByLevel(req, res, args[2]) if args[1] is 'find_by_level'
    super arguments...

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

  findByLevel: (req, res, levelOriginal) ->
    return @sendUnauthorizedError(res) if not req.user?
    # Find all CourseInstances that req.user is a part of that match the given level.
    CourseInstance.find {_id: {$in: req.user.get('courseInstances')}},  (err, courseInstances) =>
      return @sendDatabaseError res, err if err
      return @sendSuccess res, [] unless courseInstances.length
      courseIDs = _.uniq (ci.get('courseID') for ci in courseInstances)
      Course.find {_id: {$in: courseIDs}}, {name: 1, campaignID: 1}, (err, courses) =>
        return @sendDatabaseError res, err if err
        return @sendSuccess res, [] unless courses.length
        campaignIDs = _.uniq (c.get('campaignID') for c in courses)
        Campaign.find {_id: {$in: campaignIDs}, "levels.#{levelOriginal}": {$exists: true}}, {_id: 1}, (err, campaigns) =>
          return @sendDatabaseError res, err if err
          return @sendSuccess res, [] unless campaigns.length
          courses = _.filter courses, (course) -> _.find campaigns, (campaign) -> campaign.get('_id').toString() is course.get('campaignID').toString()
          courseInstances = _.filter courseInstances, (courseInstance) -> _.find courses, (course) -> course.get('_id').toString() is courseInstance.get('courseID').toString()
          return @sendSuccess res, courseInstances

  get: (req, res) ->
    if ownerID = req.query.ownerID
      return @sendForbiddenError(res) unless req.user and (req.user.isAdmin() or ownerID is req.user.id)
      return @sendBadInputError(res, 'Bad ownerID') unless utils.isID ownerID
      CourseInstance.find {ownerID: mongoose.Types.ObjectId(ownerID)}, (err, courseInstances) =>
        return @sendDatabaseError(res, err) if err
        return @sendSuccess(res, (@formatEntity(req, courseInstance) for courseInstance in courseInstances))
    else if memberID = req.query.memberID
      return @sendForbiddenError(res) unless req.user and (req.user.isAdmin() or memberID is req.user.id)
      return @sendBadInputError(res, 'Bad memberID') unless utils.isID memberID
      CourseInstance.find {members: mongoose.Types.ObjectId(memberID)}, (err, courseInstances) =>
        return @sendDatabaseError(res, err) if err
        return @sendSuccess(res, (@formatEntity(req, courseInstance) for courseInstance in courseInstances))
    else if classroomID = req.query.classroomID
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

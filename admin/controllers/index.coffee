Spine       = require('spine/core')
require('spine/route')
require('spine/manager')
require('lib/spine-couch-ajax')
require('lib/spine-couch-changes')
require('lib/fastclick')

templates   = require('duality/templates')
session     = require('session')

MainNav     = require('controllers/main-nav')
MainStack   = require('controllers/main-stack')
HelpUI      = require('controllers/ui/help')

Site        = require('models/site')
Author      = require('models/author')
Collection  = require('models/collection')
Essay       = require('models/essay')
Video       = require('models/video')
Scene       = require('models/scene')
Block       = require('models/block')
Contact     = require('models/contact')
Sponsor     = require('models/sponsor')
Redirect    = require('models/redirect')


class App extends Spine.Controller
  
  constructor: ->
    super
    @appStarted = false
    @mainNav = new MainNav
    @append @mainNav
    @initApp()

  initApp: =>
    @mainStack = new MainStack
    @helpUI    = new HelpUI
    @append @mainStack, @helpUI
    Spine.Route.setup()
    
    @setupSession()
    @hookPanelsToNav()
    @setupOnlineOffline()
    @doOtherStuff()

  setupSession: ->
    session.on 'change', @checkRole
    @getSessionInfo()

  getSessionInfo: =>
    session.info (err, info) =>
      if not info
        # try again in 5 seconds
        @mainNav.offline.show()
        @delay @getSessionInfo, 5000
      else
        @mainNav.offline.hide()
        @checkRole info.userCtx

  checkRole: (userCtx) =>
    if userCtx?.roles and 'manager' in userCtx.roles
      @mainNav.hideLogin()
      @mainNav.greetUser(userCtx.name)
      @startApp()
      @mainStack.el.css('visibility', 'visible')
      @helpUI.el.css('visibility', 'visible')
    else
      @mainNav.showLogin()
      @endApp()
      @mainStack.el.css('visibility', 'hidden')
      @helpUI.el.css('visibility', 'hidden')

  startApp: =>
    unless @appStarted
      @loadData()
      @navigate('/')
      @appStarted = true

  endApp: =>
    if @appStarted
      @unloadData()
      @mainStack.filterBox.reset()
      @appStarted = false

  loadData: =>
    # Load data models
    Site.fetch()
    Author.fetch()
    Collection.fetch()
    Essay.fetch()
    Video.fetch()
    Scene.fetch()
    Block.fetch()
    Contact.fetch()
    Sponsor.fetch()
    Redirect.fetch()
    @dataLoaded = true

  unloadData: =>
    # Empty data from client models
    Site.deleteAll()
    Author.deleteAll()
    Collection.deleteAll()
    Essay.deleteAll()
    Video.deleteAll()
    Scene.deleteAll()
    Block.deleteAll()
    Contact.deleteAll()
    Sponsor.deleteAll()
    Redirect.deleteAll()
    @dataLoaded = false

  hookPanelsToNav: ->
    cls = @
    for k, v of @mainStack.controllers
      @mainStack[k].active -> cls.mainNav.selectFromClassName(@className)

  setupOnlineOffline: ->   
    if not navigator.onLine
      @mainNav.offline.show()
      
    $(window).on 'offline', =>
      @mainNav.offline.show()
    
    $(window).on 'online', =>
      @mainNav.offline.hide()
      @delay @getSessionInfo, 5000

  doOtherStuff: ->
    # Use the fastclick module for touch devices.
    # Add a class of `needsclick` if the original click is needed.
    new FastClick(document.body)

    # Alert user when leaving the application.
    window.onbeforeunload = (e) ->
      msg = 'Bye bye! Leaving Kleks now, but you may have unsaved items. Keep going if you are sure.'
      e = window.event if not e?
      e.returnValue = msg if e
      msg


module.exports = App
    
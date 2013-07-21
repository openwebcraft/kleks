Spine       = require('spine/core')
$           = Spine.$
templates   = require('duality/templates')
utils       = require('lib/utils')

MultiSelectUI = require('controllers/ui/multi-select')
FileUploadUI  = require('controllers/ui/file-upload')
PreviewUI     = require('controllers/ui/preview')

Video       = require('models/video')
Author      = require('models/author')
Collection  = require('models/collection')
Sponsor     = require('models/sponsor')
Site        = require('models/site')


class VideoForm extends Spine.Controller
  className: 'video form panel'

  elements:
    '.item-title':             'itemTitle'
    '.error-message':          'errorMessage'
    'form':                    'form'
    'select[name=site]':       'formSite'
    'select[name=author_id]':  'formAuthorId'
    'select[name=sponsor_id]': 'formSponsorId'
    'input[name=title]':       'formTitle'
    'input[name=published]':   'formPublished'
    'textarea[name=intro]':    'formIntro'
    'textarea[name=body]':     'formBody'
    '.collections-list':       'collectionsList'
    '.upload-ui':              'fileUploadContainer'
    '.save-button':            'saveButton'
    '.cancel-button':          'cancelButton'
    'button.fullscreen-button': 'fullscreenButton'

  events:
    'submit form':              'preventSubmit'
    'change *[name]':           'markAsDirty'
    'keyup *[name]':            'markAsDirty'
    'click .save-button':       'save'
    'click .cancel-button':     'cancel'
    'click .delete-button':     'destroy'
    'change select[name=site]': 'siteChange'
    'blur input[name=slug]':    'updateSlug'
    'click .fullscreen-button': 'fullscreen'

  constructor: ->
    super
    @active @render

  render: (params) ->
    @dirtyForm = false
    @editing = params.id?
    if @editing
      @copying = params.id.split('-')[0] is 'copy'
      if @copying
        @title = 'Copy Video'
        @item = Video.find(params.id.split('-')[1]).dup()
        # Important to indicate that we are creating a new record
        @editing = false
      else
        @item = Video.find(params.id)
        @title = @item.name
        
      # Fetch missing data if need be
      if not @item.body?
        @item.ajax().reload {},
          success: =>
            @formBody.val(@item.body)
            @formIntro.val(@item.intro)
    else
      @title = 'New Video'
      @item = {}

    @item.collections ?= []
    @item._attachments ?= {}
    
    @item.sites = Site.all().sort(Site.alphaSort)
    @item.sponsors = Sponsor.all().sort(Sponsor.alphaSort)
    @html templates.render('video-form.html', {}, @item)

    @itemTitle.html @title
    
    # Set few initial form values
    if @editing or @copying
      @formSite.val(@item.site)
      @formSponsorId.val(@item.sponsor_id)
      @formPublished.prop('checked', @item.published)
    else
      @formSite.val(@stack.stack.filterBox.siteId)
      # @formPublished.prop('checked', true)
    @siteChange()

    # Files upload area
    @fileUploadUI = new FileUploadUI
      docId: @item.id
      selectedFile: @item.photo
      attachments: @item._attachments
      changeCallback: @markAsDirty
    @fileUploadContainer.html @fileUploadUI.el

    return @

  siteChange: ->
    $siteSelected = @formSite.parents('.field').find('.site-selected')
    site = Site.exists(@formSite.val())
    if site
      $siteSelected.html "<div class=\"site-name theme-#{site.theme}\">#{site.name_html}</div>"
      @makeAuthorsList(site)
      @makeCollectionsList(site)
    else
      $siteSelected.html ""

  makeAuthorsList: (site) ->
    authors = Author.findAllByAttribute('site', site.id).sort(Author.alphaSort)
    @formAuthorId.empty()
      .append "<option value=\"\">Select an author...</option>"
    for author in authors
      @formAuthorId.append "<option value=\"#{author.id}\">#{author.name}</option>"
    @formAuthorId.val(@item.author_id)
  
  makeCollectionsList: (site) ->
    collections = Collection.findAllByAttribute('site', site.id).sort(Collection.alphaSort)
    @collectionSelectUI = new MultiSelectUI
      items: collections
      selectedItems: (c.id for c in @item.collections)
      valueFields: ['id','slug']
      changeCallback: @markAsDirty
    @collectionsList.html @collectionSelectUI.el

  updateSlug: (e) =>
    slug = $(e.currentTarget)
    unless slug.val()
      slug.val utils.cleanSlug(@formTitle.val())

  fullscreen: (e) =>
    e?.preventDefault()
    @fullscreenButtonText ?= @fullscreenButton.html()
    if @form.hasClass('fullscreen')
      @form.removeClass('fullscreen')
      @fullscreenButton.html @fullscreenButtonText
      @previewUI?.close()
    else
      @form.addClass('fullscreen')
      @fullscreenButton.html "Exit #{@fullscreenButtonText}"
      @previewUI = new PreviewUI field: @formBody

  save: (e) ->
    e.preventDefault()
    if not navigator.onLine
      alert "Can not save. You are OFFLINE."
      return

    if @editing
      @item.fromForm(@form)
    else
      @item = new Video().fromForm(@form)

    @item.collections = @collectionSelectUI.selected()
    @item._attachments = @fileUploadUI.attachments

    # Take care of some boolean checkboxes
    @item.published = @formPublished.is(':checked')
    
    # Save the item and make sure it validates
    if @item.save()
      @back()
    else
      msg = @item.validate()
      @showError msg

    return @

  showError: (msg) ->
    @errorMessage.html(msg).show()
    @el.scrollTop(0)
  
  destroy: (e) ->
    e.preventDefault()
    if @item and confirm "Are you sure you want to delete this item?"
      @item.destroy()
      @back()

  markAsDirty: =>
    @dirtyForm = true
    @saveButton.addClass('glow')

  cancel: (e) ->
    e.preventDefault()
    if @dirtyForm
      if confirm "You may have some unsaved changes.\nAre you sure you want to proceed?"
        @back()
    else
      @back()

  back: ->
    @navigate('/videos/list')

  preventSubmit: (e) ->
    e.preventDefault()
    return false
    
  deactivate: ->
    @el.scrollTop(0)
    super


class VideoList extends Spine.Controller
  className: 'video list panel fixed-header'

  events:
    'click h1 .count':    'reload'

  constructor: ->
    super
    # @active @render
    Video.bind 'change refresh', @render
    Spine.bind 'filterbox:change', @filter

  render: =>
    sortFunc = if @filterObj?.sortBy then Video[@filterObj.sortBy] else Video.dateSort
    context = 
      videos: Video.filter(@filterObj).sort(sortFunc)
    @html templates.render('videos.html', {}, context)

  filter: (@filterObj) =>
    @render()
    @el.scrollTop(0)

  reload: ->
    Video.fetch()


class Videos extends Spine.Stack
  className: 'videos panel'

  controllers:
    list: VideoList
    form: VideoForm

  default: 'list'

  routes:
    '/videos/list': 'list'
    '/video/new':   'form'
    '/video/:id':   'form'

  constructor: ->
    super
    for k, v of @controllers
      @[k].active => @active()


module.exports = Videos
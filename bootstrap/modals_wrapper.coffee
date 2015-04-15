# Wrapper on top of the bootstrap modal plugin.
# Use the ModalComponent when wanting to create a simple modal.
# Use the ModalRemoteComponent when the modal's content is a remote resource.
# Use the ModalFormComponent when the modal's content is a remote form.

# Options: title, content, confirmable, confirmButton, styles, keep
# Events: opening, opened, closing, closed, ready
@ModalComponent = class ModalComponent
  constructor: (@options) ->
    @opened = false
    @keepAlive = false
    @options ?= {}
    @options.title ?= 'Modal'
    if @options.confirmButton?
      @options.confirmable = true
    else
      @options.confirmButton = 'Confirm'
    @options.closeButton ?= 'Close'
    @quickCallbacks = {} # callbacks that are executed only once

  plugin: ->
    @modal.modal keyboard: false

  open: ->
    unless @modal
      @initModal()
      @attachHandlers()
      @renderContent()

    @show()

  # Two cases here: if the page is clean of modals, it opens the current modal as normal
  # chainShow: If the page has already an opened modal, first it hides the opened one and
  # and it opens the current one. When the current one gets closed, it shows again the previous one.
  show: (callback) ->
    @quickCallbacks['opened'] = callback
    @release() # release keep alive flag
    @chainShow() || @plugin()

  chainShow: ->
    openedModal = $('body').data 'modal'
    # if there's already an opened modal
    if openedModal
      # register a quick callback to show the openedModal when this one gets closed
      @quickCallbacks['closed'] = -> openedModal.show()
      # hides the opened modal and when the hide animation is finished, it shows this one
      openedModal.hide => @plugin()

      return true

    false

  hide: (callback) ->
    @quickCallbacks['closed'] = callback
    @keep() # keep alive
    @modal.modal 'hide'

  close: ->
    @release()
    @modal.modal 'hide'

  keep: ->
    @keepAlive = true

  release: ->
    @keepAlive = false

  initModal: ->
    @modal = $ $.modal.render @options

  attachHandlers: ->
    @modal.on 'show.bs.modal', => @fireEvent('opening')
    @modal.on 'shown.bs.modal', =>
      @lockBody()
      @fireOpened()
    @modal.on 'hide.bs.modal', => @fireEvent('closing')
    @modal.on 'hidden.bs.modal', =>
      @unlockBody()
      @fireClosed()

  renderContent: ->
    @modal.find('.modal-body').html @options.content

  fireOpened: ->
    @opened = true
    @fireEvent 'opened'
    @fireReady()

  fireClosed: ->
    # remove the modal from the DOM when closed, unless keeping
    unless @keepAlive || @options.keep
      @modal.remove()
      @modal = null
    @fireEvent 'closed'

  fireReady: ->
    @fireEvent('ready') if @isReady()

  isReady: -> @opened

  fireEvent: (eventName) ->
    @options[eventName](@modal) if @options[eventName]
    if @quickCallbacks[eventName]
      @quickCallbacks[eventName](@modal)
      @quickCallbacks[eventName] = null

  lockBody: ->
    $('body')
      .addClass('modal-open')
      .data('modal', @)
      .on 'keyup', (e) =>
        @close() if !@overlayed() && e.keyCode is 27 # ESC key

  unlockBody: ->
    $('body')
      .removeClass('modal-open')
      .data('modal', null)
      .off 'keyup'

  overlayed: ->
    # slimbox overlay
    $('#lbOverlay').is(':visible')

# Options: load
# Events: loaded
@ModalRemoteComponent = class ModalRemoteComponent extends ModalComponent
  constructor: (@options) ->
    super @options
    @loaded = false

  renderContent: ->
    @modal.find('.modal-body')
      .html('<p style="color: #C0C0C0;">Carregando...</p>')
      .load @options.load, => @contentLoaded()

  contentLoaded: ->
    @loaded = true
    @fireLoaded()

  fireLoaded: ->
    @fireEvent 'loaded'
    @fireReady()

  isReady: ->
    super && @loaded

# Options: successMsg, errorMsg
# Events: beforeSubmit, onSuccess
@ModalFormComponent = class ModalFormComponent extends ModalRemoteComponent
  constructor: (@options) ->
    super @options
    @options.confirmable = true

  contentLoaded: ->
    super
    @modal.find('form .actions').hide()

  attachHandlers: ->
    super
    @modal.find('.btn.confirm').click => @submitForm()

  submitForm: ->
    $form = @modal.find 'form'
    @submitThroughActions($form) || @makeAjaxCall($form)

  submitThroughActions: ($form) ->
    $submitAction = $form.find '.actions [type="submit"]'
    if $submitAction.length != 0
      $form
        .one 'ajax:beforeSend', => @beforeSubmit()
        .one 'ajax:success', (ev, data, status, xhr) => @onSuccess(data, status, xhr)
        .one 'ajax:error', (ev, xhr) => @onError(xhr)
      $submitAction.click()
      return true
    false

  makeAjaxCall: ($form) ->
    $.ajax
      type: $form.attr('method')
      url: $form.attr('action')
      data: $form.serialize()
      dataType: $form.attr('format') || 'html'
      beforeSend: => @beforeSubmit()
      success: (data, status, xhr) => @onSuccess(data, status, xhr)
      error: (xhr) => @onError(xhr)

  beforeSubmit: ->
    @options.beforeSubmit() if @options.beforeSubmit

  onSuccess: (data, status, xhr) ->
    @modal.modal 'hide'
    if @options.successMsg isnt false
      $.modal.notifySuccess @options.successMsg || 'Success!'
    if @options.onSuccess
      ct = xhr.getResponseHeader('content-type') || ''
      data = JSON.parse(data) if ct.indexOf('json') > -1 && typeof(data) is 'string'
      @options.onSuccess(data, status, xhr)

  onError: (xhr) ->
    @modal.find('.modal-body').html xhr.responseText
    if @options.errorMsg isnt false
      $.modal.notifyError "#{@options.errorMsg || 'Error! Try again.'}"


# Useful jQuery plugins

$.modal = (options) ->
  new ModalComponent(options).open()

$.modal.remote = (options) ->
  new ModalRemoteComponent(options).open()

$.modal.form = (options) ->
  new ModalFormComponent(options).open()


# Adapters

$.modal.render = (options) ->
  # Use some templating system to render the modals. E.g: HoganTemplates['modal'].render options
  return

$.modal.notifySuccess = (msg) ->
  # Use some growl notification system or anything else
  return

$.modal.notifyError = (msg) ->
  # Use some growl notification system or anything else
  return

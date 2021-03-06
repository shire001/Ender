window.onload = () ->
  React = require 'react'
  ReactDOM = require 'react-dom'
  fs = require 'fs'
  {ipcRenderer} = require 'electron'
  update = require 'react-addons-update'
  Engine = require './js/renderer/engine'
  MessageBox = require './js/renderer/MessageBox'
  NameBox = require './js/renderer/NameBox'
  ImageView = require './js/renderer/ImageView'
  HistoryView = require './js/renderer/HistoryView'
  Setting = require './js/renderer/Setting'
  Audios = require './js/renderer/Audios'
  effects = require './js/renderer/effects'
  utils = require './js/renderer/utils'
  {Config} = require './js/renderer/Config'
  utils.load()

  Contents = React.createClass
    getInitialState: ->
      mode: "main"
      message: null
      images: []
      audios: {}
      refs: {}
      tls: null
    componentWillMount: ->
      config = JSON.parse fs.readFileSync('dist/resource/config.json', 'utf8')
      @config = new Config config
      @audioContext = new AudioContext()
    componentDidMount: ->
      console.log "start!"
      # config = JSON.parse fs.readFileSync('dist/resource/config.json', 'utf8')
      # @config = new Config config
      window.addEventListener("keydown", @onKeyDown)
      window.addEventListener("wheel", @onScroll)
      ipcRenderer.on 'show-setting', =>
        @changeMode "setting"
      Action = {@setText, @setName, @setImage, @clearImage, @clear, @startAnimation, @setConfig, @loadAudio, @playAudio, @stopAudio}
      @engine = new Engine(Action, @config)
      # @setState config: config, @engine.exec
      @engine.exec()
    componentWillUnmount: ->
      window.removeEventListener("keydown", @onKeyDown)
      window.removeEventListener("scroll", @onScroll)
    changeMode: (mode) ->
      unless mode is "main"
        diff = {}
        diff.auto = $set: false
        @setConfig "auto", false
      @setState mode: mode
    Pause: ->
      @setConfig "auto", false

    startAnimation: (target, effectName, callback) ->
      @tls = []
      @engine.startAnimation()
      nodes = document.querySelectorAll target
      nodes = document.getElementsByClassName(target) if nodes.length < 1
      cb = =>
        callback?()
        @engine.finishAnimation()
        @autoExec()
      for node in nodes
        @tls.push effects[effectName](node, cb)
        cb = null
    finishAnimation: (className) ->
      for tl in @tls
        tl.progress(1, false)
      @tls = null
      @engine.finishAnimation()
    setText: (message, cb) ->
      @setState message: message
      , cb
    setName: (name) ->
      @setState name: name
    setImage: (image) ->
      if image.effect?
        callback = => @startAnimation(image.className, image.effect)
      else
        callback = => @autoExec()
      @setState
        images: @state.images.concat(image)
        , callback
    #target: className(string), effect: name(string)
    clearImage: (target, effect) ->
      images = []
      if target?
        for image in @state.images
          if image.className isnt target
            images.push image
      cb = =>
        @setState
          images: images
      if effect?
        @startAnimation(target, effect, cb)
    loadAudio: (audio) ->
      # merge audio style, Config(default) style and Option style
      style = if @config.audio.hasOwnProperty audio.type then @config.audio[audio.type] else {}
      if audio.option
        style.forIn (key, value) ->
          if audio.option.hasOwnProperty key
            style[key] = audio.option[key]
      newAudios = {}
      newAudios[audio.name] = audio
      if style.loop && style.loopStart > 0
        newAudios["#{audio.name}_loop"] =
          "type": audio.type,
          "name": "#{audio.name}_loop",
          "src": "#{audio.src}#t=#{style.loopStart}"
          "option": if audio.option? then audio.option else {}
        newAudios["#{audio.name}_loop"].option.loopStart = 0
      newAudios = update @state.audios,
       "$merge": newAudios
      @setState () ->
        audios: newAudios
    setAudioNode: (name, dom) ->
      if @state.audios[name]?
        node = @audioContext.createMediaElementSource dom
        @state.audios[name].node = node
    playAudio: (name) ->
      if @state.audios[name]?
        @state.audios[name].node.connect @audioContext.destination
        (document.getElementById "audio-#{name}").play()
    stopAudio: (name) ->
      if @state.audios[name]?
        (document.getElementById "audio-#{name}").stop()

    clear: ->
      @setState
        message: null
        images: []
    setConfig: (key, value) ->
      if value?
        @config[key] = value
      else
        @config = key
      @engine?.config = @config
      @autoExec()
      # config = update(@state.config, diff)
      # @engine?.config = config
      # @setState config: config, => @autoExec()
    onClick: (e) ->
      switch @state.mode
        when "main"
          if @state.history?
            @setState history: null
          else
            diff = {}
            diff.auto = $set: false
            @setConfig "auto", false
            if @engine.isAnimated and @tls?
              @finishAnimation()
            else
              @engine?.exec()
    onKeyDown: (e) ->
      switch @state.mode
        when "main"
          @onClick() if e.keyCode is 13
        when "setting"
          @setState mode: "main" if e.keyCode is 27
    onScroll: (e) ->
      switch @state.mode
        when "main"
          if e.deltaY < 0 and !@state.history?
            diff = {}
            diff.auto = $set: false
            @setConfig "auto", false
            @setState history: @engine?.history
    autoExec: ->
      @engine.autoExec()
    render: () ->
      items = []
      switch @state.mode
        when "main"
          if @state.name?
            items.push <NameBox key="name" name={@state.name} />
          if @state.history?
            items.push <HistoryView key="history" history={@state.history} />
          if @state.message?.length > 0 && !@config.hideMessageBox
            items.push <MessageBox key="message" styles={@config.text.styles} message={@state.message}/>
          items.push <ImageView key="images" images={@state.images} />
        when "setting"
          items.push <Setting key="setting" config={@config} Action={{@setConfig, @changeMode}} />
      items.push <Audios key="audios" audios={@state.audios} config={@config.audio}
        Action={
          "setAudio": @setAudioNode
          "playAudio": @playAudio
        }
      />
      return (
        <div id="inner" onClick={@onClick}>
          {items}
        </div>
      )
  ReactDOM.render(
    <Contents />
    document.getElementById 'contents'
  )

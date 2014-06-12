#= require trix/utilities/dom

class Trix.TextView
  constructor: (@text, @blockPosition) ->
    @textAttributes = @text.getAttributes()

  # Rendering

  render: ->
    @resetNodeCache()
    @elements = []
    @createElementsForText()
    @createExtraNewlineElement()

    container = switch
      when @textAttributes.quote
        document.createElement("blockquote")
      else
        document.createDocumentFragment()

    container.appendChild(element) for element in @elements
    container

  resetNodeCache: ->
    @nodeCache = []

  # Hold a reference to every node we create to prevent IE from losing
  # their expando properties like trixPosition. IE will otherwise occasionally
  # replace the nodes or remove the properties (uncertain which one).
  cacheNode: (node) ->
    @nodeCache.push(node)

  createElementsForText: ->
    @text.eachRun (run) =>
      @previousRun = @currentRun
      @currentRun = run
      @createElementForCurrentRun()

  createElementForCurrentRun: ->
    {attributes, position} = @currentRun

    parentAttribute = @getParentAttribute()
    elements = createElementsForAttributes(attributes, parentAttribute)

    element = innerElement = elements[0]
    element.trixPosition = position
    element.trixBlock = @blockPosition
    @cacheNode(element)

    for child in elements[1..]
      @cacheNode(child)
      innerElement.appendChild(child)
      innerElement = child
      innerElement.trixPosition = position
      innerElement.trixBlock = @blockPosition

    if @currentRun.attachment
      if attachmentElement = @createAttachmentElementForCurrentRun()
        @cacheNode(attachmentElement)
        innerElement.appendChild(attachmentElement)
    else if @currentRun.string
      for node in @createStringNodesForCurrentRun()
        @cacheNode(node)
        innerElement.appendChild(node)

    if parentAttribute
      @elements[@elements.length - 1].appendChild(element)
    else
      @elements.push(element)

  getParentAttribute: ->
    if @previousRun
      for key, value of @currentRun.attributes when Trix.attributes[key]?.parent
        return key if value is @previousRun.attributes[key]

  # Add an extra newline if the text ends with one. Otherwise, the cursor won't move down.
  createExtraNewlineElement: ->
    if string = @currentRun?.string
      if /\n$/.test(string)
        @currentRun = { string: "\n", position: @text.getLength() }
        node = @createStringNodesForCurrentRun()[0]
        @cacheNode(node)
        @elements.push(node)

  createAttachmentElementForCurrentRun: ->
    {attachment, attributes, position} = @currentRun

    attachment.view ?= Trix.AttachmentView.for(attachment)
    attachment.element ?= attachment.view.render()
    attachment.view.resize(width: attributes.width, height: attributes.height)

    element = attachment.element
    element.trixPosition = position
    element.trixLength = 1
    element.trixAttachmentId = attachment.id
    element

  createStringNodesForCurrentRun: ->
    {string, position} = @currentRun
    nodes = []

    for substring, index in string.split("\n")
      if index > 0
        node = document.createElement("br")
        node.trixPosition = position
        node.trixBlock = @blockPosition
        position += 1
        node.trixLength = 1
        nodes.push(node)

      if length = substring.length
        node = document.createTextNode(preserveSpaces(substring))
        node.trixPosition = position
        node.trixBlock = @blockPosition
        position += length
        node.trixLength = length
        nodes.push(node)

    nodes

  createElementsForAttributes = (attributes, parentAttribute) ->
    elements = []
    styles = []

    for key, value of attributes when config = Trix.attributes[key]
      if config.style
        styles.push(config.style)

      if config.tagName
        unless config.parent and key is parentAttribute
          element = document.createElement(config.tagName)
          element.setAttribute(key, value) unless typeof(value) is "boolean"

          if config.parent
            elements.unshift(element)
          else
            elements.push(element)

    unless elements.length
      if styles.length
        elements.push(document.createElement("span"))
      else
        elements.push(document.createDocumentFragment())

    for style in styles
      elements[0].style[key] = value for key, value of style

    elements

  preserveSpaces = (string) ->
    string
      # Replace two spaces with a space and a non-breaking space
      .replace(/\s{2}/g, " \u00a0")
      # Replace leading space with a non-breaking space
      .replace(/^\s{1}/, "\u00a0")
      # Replace trailing space with a non-breaking space
      .replace(/\s{1}$/, "\u00a0")

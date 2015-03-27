React = require 'react'
handleInputChange = require '../../lib/handle-input-change'
PromiseRenderer = require '../../components/promise-renderer'
apiClient = require '../../api/client'
ChangeListener = require '../../components/change-listener'
Papa = require 'papaparse'

NOOP = Function.prototype

VALID_SUBJECT_EXTENSIONS = ['.jpg', '.png', '.gif', '.svg']
INVALID_FILENAME_CHARS = [';'] # TODO: Figure out a good general way to separate filenames.

UploadDropTarget = React.createClass
  displayName: 'UploadDropTarget'

  getDefaultProps: ->
    accept: 'text/plain'
    multiple: false
    onSelect: NOOP

  getInitialState: ->
    dragEntered: false

  eventsToMakeDropWork: ->
    onDragEnter: @handleDrag.bind this, true
    onDragExit: @handleDrag.bind this, false
    onDragOver: @handleDrag.bind this, null

  hiddenInputStyle:
    height: 0
    opacity: 0
    position: 'absolute'
    width: 0

  render: ->
    style =
      outline: if @state.dragEntered
        '1px solid green'
      else
        '1px dashed gray'
      padding: '0.5em 1em'
      position: 'relative'

    <label className="upload-drop-target" style={style} {...@eventsToMakeDropWork()} onDrop={@handleDrop}>
      <input type="file" accept={@props.accept} multiple={@props.multiple} onChange={@handleFileSelection} style={@hiddenInputStyle} />
      {@props.children}
    </label>

  handleDrag: (enter, e) ->
    e.stopPropagation()
    e.preventDefault()
    if enter?
      @setState dragEntered: enter

  handleDrop: (e) ->
    e.stopPropagation()
    e.preventDefault()
    @props.onSelect e.dataTransfer.files
    @setState dragEntered: false

  handleFileSelection: (e) ->
    @props.onSelect e.target.files

ManifestView = React.createClass
  displayName: 'ManifestView'

  getDefaultProps: ->
    name: ''
    errors: []
    subjects: []
    files: {}
    onRemove: NOOP

  getInitialState: ->
    showingErrors: false
    showingMissing: false
    showingReady: false

  render: ->
    missingFiles = []
    subjectsReadyToGo = []
    subjectsWithMissingFiles = []

    for subject in @props.subjects
      allLocationsHaveFiles = true
      for location in subject.locations
        unless location of @props.files
          missingFiles.push location
          allLocationsHaveFiles = false
      if allLocationsHaveFiles
        subjectsReadyToGo.push subject
      else
        subjectsWithMissingFiles.push subject

    <div className="manifest-view">
      <div><strong>{@props.name}</strong> ({@props.subjects.length} subjects)</div>

      {unless @props.errors.length is 0
        <div>
          <i className="fa fa-exclamation-triangle fa-fw" style={color: 'orange'}></i>
          {@props.errors.length} parse errors{' '}
          <button type="button" className="secret-button" onClick={@toggleState.bind this, 'showingErrors'}>
            <i className="fa fa-eye fa-fw"></i>
          </button>
          <br />
          {if @state.showingErrors
            <ul>
              {for {row, message} in @props.errors
                <li key={row + message}>Row {row}: {message}</li>}
            </ul>}
        </div>}

      {unless missingFiles.length is 0
        <div>
          <i className="fa fa-exclamation-circle fa-fw" style={color: 'red'}></i>
          {missingFiles.length} missing files from {subjectsWithMissingFiles.length} subjects{' '}
          <button type="button" className="secret-button" onClick={@toggleState.bind this, 'showingMissing'}>
            <i className="fa fa-eye fa-fw"></i>
          </button>
          <br />
          {if @state.showingMissing
            <ul>
              {for file, i in missingFiles
                <li key={i}>{file}</li>}
            </ul>}
        </div>}

      <div>
        <i className="fa fa-thumbs-up fa-fw" style={color: 'green'}></i>
        {subjectsReadyToGo.length} subjects ready to load{' '}
        <button type="button" className="secret-button" onClick={@toggleState.bind this, 'showingReady'}>
          <i className="fa fa-eye fa-fw"></i>
        </button>
        {if @state.showingReady
          <ul>
            {for {locations, metadata}, i in subjectsReadyToGo
              <li key={i}>
                {for location in locations
                  <div key={location}>{location}</div>}
                <table>
                  <tr>
                    {for key, value of metadata
                      <th key={key}>{key}</th>}
                  </tr>
                  <tr>
                    {for key, value of metadata
                      <td key={key}>{value}</td>}
                  </tr>
                </table>
              </li>}
          </ul>}
      </div>
    </div>

  toggleState: (key) ->
    newState = {}
    newState[key] = not @state[key]
    @setState newState

EditSubjectSetPage = React.createClass
  displayName: 'EditSubjectSetPage'

  getDefaultProps: ->
    subjectSet: null

  getInitialState: ->
    manifests: {}
    files: {}

  render: ->
    <div>
      <p><small>TODO</small></p>

      <p>
        Name<br />
        <input type="text" name="display_name" value={@props.subjectSet.display_name} onChange={handleInputChange.bind @props.subjectSet} />
      </p>

      <p>Subjects: {@props.subjectSet.set_member_subjects_count}</p>

      <p>
        (<small>TODO</small> Retirement rules editor)
      </p>

      <p>
        <UploadDropTarget onSelect={@handleFileSelection}>Add subjects and manifests</UploadDropTarget>
      </p>

      {if Object.keys(@state.manifests).length is 0
        <div>TODO: List subjects without a manifest</div>
      else
        <div className="manifests-and-subjects">
          Manifests
          <br />
          <ul>
            {for name, {errors, subjects} of @state.manifests
              <li key={name}><ManifestView name={name} errors={errors} subjects={subjects} files={@state.files} /></li>}
          </ul>
        </div>}
    </div>

  handleFileSelection: (files) ->
    for file in files
      if file.type in ['text/csv', 'text/tab-separated-values']
        @_addManifest file
        gotManifest = true
      else if file.type.indexOf('image/') is 0
        @state.files[file.name] = file
        gotFile = true

      if gotFile and not gotManifest
        @forceUpdate()

  _addManifest: (file) ->
    reader = new FileReader
    reader.onload = (e) =>
      # TODO: Look into PapaParse features.
      # Maybe wan we parse the file object directly in a worker.
      {data, errors} = Papa.parse e.target.result, header: true, dynamicTyping: true

      metadatas = for rawData in data
        cleanData = {}
        for key, value of rawData
          cleanData[key.trim()] = value?.trim?() ? value
        cleanData

      subjects = []
      for metadata in metadatas
        locations = @_findFilesInMetadata metadata
        unless locations.length is 0
          subjects.push {locations, metadata}

      @state.manifests[file.name] = {errors, subjects}
      @forceUpdate()

    reader.readAsText file

  _findFilesInMetadata: (metadata) ->
    filesInMetadata = []
    for key, value of metadata
      filesInValue = value.match? ///([^#{INVALID_FILENAME_CHARS.join ''}]+(?:#{VALID_SUBJECT_EXTENSIONS.join '|'}))///gi
      if filesInValue?
        filesInMetadata.push filesInValue...
    filesInMetadata

  handleRemoveManifest: (name) ->
    delete @state.manifests[name]
    @forceUpdate();

module.exports = React.createClass
  displayName: 'EditSubjectSetPageWrapper'

  getDefaultProps: ->
    params: null

  render: ->
    <PromiseRenderer promise={apiClient.type('subject_sets').get @props.params.subjectSetID}>{(subjectSet) =>
      <ChangeListener target={subjectSet}>{=>
        <EditSubjectSetPage {...@props} subjectSet={subjectSet} />
      }</ChangeListener>
    }</PromiseRenderer>

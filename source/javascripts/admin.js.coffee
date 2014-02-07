adminApp = angular.module "adminApp", ["ngCookies"]

adminApp.config ["$locationProvider", ($locationProvider) ->
  $locationProvider.html5Mode(true)
  $locationProvider.hashPrefix('!')
]

adminApp.controller "AdminIndexCtrl", ["$scope", "$location", "$q", "$cookieStore", ($scope, $location, $q, $cookieStore) ->
  $scope.host = $location.search()["host"] || $location.host()
  $scope.port = $location.search()["port"] || if $scope.host == "sandbox.influxdb.org" then 9061 else 8086
  $scope.database = $location.search()["database"] || $cookieStore.get("database")
  $scope.username = $location.search()["username"] || $cookieStore.get("username")
  $scope.password = $location.search()["password"] || $cookieStore.get("password")
  $scope.authenticated = false
  $scope.isClusterAdmin = false
  $scope.databases = []
  $scope.admins = []
  $scope.data = []
  $scope.readQuery = null
  $scope.writeSeriesName = null
  $scope.writeValues = null
  $scope.successMessage = "OK"
  $scope.alertMessage = "Error"
  $scope.authMessage = ""
  $scope.queryMessage = ""
  $scope.selectedPane = "databases"
  $scope.newDbUser = {}
  $scope.interfaces = []
  $scope.databaseUsers = []
  $scope.successMessage = ""
  $scope.failureMessage = ""

  $scope.newAdminUsername = null
  $scope.newAdminPassword = null

  window.influxdb = null

  $scope.alertSuccess = (msg) ->
    $scope.successMessage = msg
    $("#alert-success").show().delay(2500).fadeOut(500)

  $scope.alertFailure = (msg) ->
    $scope.failureMessage = msg
    $("#alert-failure").show().delay(2500).fadeOut(500)

  $scope.getHashParams = () ->
    $location.search()

  $scope.setHashParams = (params) ->
    $location.search(params)

  $scope.getInterfaces = () ->
    $q.when(window.influxdb.getInterfaces()).then (response) ->
      $scope.interfaces = response

  $scope.humanize = (title) ->
    title.replace(/_/g, ' ').replace /(\w+)/g, (match) ->
      match.charAt(0).toUpperCase() + match.slice(1);

  $scope.setCurrentInterface = (i) ->
    $("iframe").prop("src", "/interfaces/#{i}")
    $scope.selectedPane = "data"

  $scope.authenticateUser = () ->
    if $scope.database
      $scope.authenticateAsDatabaseAdmin()
    else
      $scope.authenticateAsClusterAdmin()

  $scope.authenticateAsClusterAdmin = () ->
    window.influxdb = new InfluxDB
      host: $scope.host
      port: $scope.port
      username: $scope.username
      password: $scope.password

    $q.when(window.influxdb.authenticateClusterAdmin()).then (response) ->
      $scope.getInterfaces()
      $scope.authenticated = true
      $scope.isClusterAdmin = true
      $scope.isDatabaseAdmin = false
      $scope.getDatabases()
      $scope.getClusterAdmins()
      $scope.selectedPane = "databases"
      $scope.storeAuthenticatedCredentials()

      $location.search({})
    , (response) ->
      $scope.alertFailure("Couldn't authenticate cluster admin: #{response.responseText}")

  $scope.authenticateAsDatabaseAdmin = () ->
    window.influxdb = new InfluxDB
      host: $scope.host
      port: $scope.port
      username: $scope.username
      password: $scope.password
      database: $scope.database

    $q.when(window.influxdb.authenticateDatabaseUser($scope.database)).then (response) ->
      $scope.getInterfaces()
      $scope.authenticated = true
      $scope.isDatabaseAdmin = true
      $scope.isClusterAdmin = false
      $scope.selectedPane = "data"
      $scope.setCurrentInterface("default")
      $location.search({})
      $scope.storeAuthenticatedCredentials()
    , (response) ->
      $scope.alertFailure("Couldn't authenticate database user: #{response.responseText}")

  $scope.storeAuthenticatedCredentials = () ->
    $cookieStore.put("username", $scope.username)
    $cookieStore.put("password", $scope.password)
    $cookieStore.put("database", $scope.database)
    $cookieStore.put("host", $scope.host)
    $cookieStore.put("port", $scope.port)

  $scope.getDatabases = () ->
    $q.when(window.influxdb.getDatabases()).then (response) ->
      $scope.databases = response

  $scope.getClusterAdmins = () ->
    $q.when(window.influxdb.getClusterAdmins()).then (response) ->
      $scope.admins = response

  $scope.createClusterAdmin = () ->
    $q.when(window.influxdb.createClusterAdmin($scope.newAdminUsername, $scope.newAdminPassword)).then (response) ->
      $scope.alertSuccess("Successfully created user: #{$scope.newAdminUsername}")
      $scope.newAdminUsername = null
      $scope.newAdminPassword = null
      $scope.getClusterAdmins()
    , (response) ->
      $scope.alertFailure("Failed to create user: #{response.responseText}")

  $scope.createDatabase = () ->
    $q.when(window.influxdb.createDatabase($scope.newDatabaseName)).then (response) ->
      $scope.alertSuccess("Successfully created database: #{$scope.newDatabaseName}")
      $scope.newDatabaseName = null
      $scope.getDatabases()
    , (response) ->
      $scope.alertFailure("Failed to create database: #{response.responseText}")

  $scope.createDatabaseUser = () ->
    $q.when(window.influxdb.createUser($scope.selectedDatabase, $scope.newDbUser.username, $scope.newDbUser.password)).then (response) ->
      $scope.alertSuccess("Successfully created user: #{$scope.newDbUser.username}")
      $scope.newDbUser = {}
      $scope.getDatabaseUsers()
    , (response) ->
      $scope.alertFailure("Failed to create user: #{response.responseText}")

  $scope.deleteDatabase = (name) ->
    $q.when(window.influxdb.deleteDatabase(name)).then (response) ->
      $scope.alertSuccess("Successfully removed database: #{name}")
      $scope.getDatabases()
    , (response) ->
      $scope.alertFailure("Failed to remove database: #{response.responseText}")

  $scope.authError = (msg) ->
    $scope.authMessage = msg
    $("span#authFailure").show().delay(1500).fadeOut(500)

  $scope.error = (msg) ->
    $scope.alertMessage = msg
    $("span#writeFailure").show().delay(1500).fadeOut(500)

  $scope.success = (msg) ->
    $scope.successMessage = msg
    $("span#writeSuccess").show().delay(1500).fadeOut(500)

  $scope.filteredColumns = (datum) ->
    datum.columns.filter (d) -> d != "time" && d != "sequence_number"

  $scope.columnPoints = (datum, column) ->
    index = datum.columns.indexOf(column)
    datum.points.map (row) ->
      time: new Date(row[0])
      value: row[index]

  $scope.getDatabaseUsers = () ->
    $q.when(window.influxdb.getDatabaseUsers($scope.selectedDatabase)).then (response) ->
      $scope.databaseUsers = response

  $scope.showDatabase = (database) ->
    $scope.selectedDatabase = database.name
    $scope.getDatabaseUsers()
]

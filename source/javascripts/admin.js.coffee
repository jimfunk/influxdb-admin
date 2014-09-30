adminApp = angular.module "adminApp", ["ngCookies"]

adminApp.config ["$locationProvider", ($locationProvider) ->
  $locationProvider.html5Mode(true)
  $locationProvider.hashPrefix('!')
]

adminApp.controller "AdminIndexCtrl", ["$scope", "$location", "$q", "$cookieStore", ($scope, $location, $q, $cookieStore) ->
  $scope.host = $location.search()["host"] || $cookieStore.get("host") || $location.host()
  $scope.port = $location.search()["port"] || $cookieStore.get("port")
  $scope.database = $location.search()["database"] || $cookieStore.get("database")
  $scope.username = $location.search()["username"] || $cookieStore.get("username")
  $scope.password = $location.search()["password"] || $cookieStore.get("password")
  $scope.ssl = $cookieStore.get("ssl") || false
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
  $scope.selectedSubPane = "users"
  $scope.newDbUser = {}
  $scope.interfaces = []
  $scope.databaseUsers = []
  $scope.databaseUser = null
  $scope.successMessage = ""
  $scope.failureMessage = ""
  $scope.shardSpaces = []
  $scope.shardSpaceDurations = ["15m", "30m", "1h", "4h", "12h", "1d", "7d", "30d", "180d"]
  $scope.shardSpaceRetentionPolicies = ["1h", "4h", "12h", "1d", "7d", "30d", "60d", "90d", "180d", "365d", "730d", "inf"]
  $scope.shardSpaceReplicationFactors = [1, 3, 4, 5, 6]
  $scope.shardSpaceSplits = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]


  $scope.newAdminUsername = null
  $scope.newAdminPassword = null

  $scope.newUserPassword = null
  $scope.newUserPasswordConfirmation = null

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
    $("iframe").prop("src", "interfaces/#{i}")
    $scope.selectedPane = "data"

  $scope.showDefaultInterface = (databaseName) ->
    window.influxdb.database = databaseName
    $("iframe").prop("src", "interfaces/default")
    $scope.selectedPane = "data"

  $scope.authenticateUser = () ->
    if $scope.database
      $scope.authenticateAsDatabaseAdmin()
    else
      $scope.authenticateAsClusterAdmin()

  $scope.authenticateAsClusterAdmin = () ->
    window.influxdb = new InfluxDB
      hosts: [$scope.host]
      port: $scope.port
      username: $scope.username
      password: $scope.password
      ssl: $scope.ssl

    $q.when(window.influxdb.authenticateClusterAdmin()).then (response) ->
      $scope.authenticated = true
      $scope.isClusterAdmin = true
      $scope.isDatabaseAdmin = false
      $scope.selectedPane = "databases"
      $scope.selectedSubPane = "users"
      $scope.storeAuthenticatedCredentials()
      $scope.getInterfaces()
      $scope.getDatabases()
      $scope.getClusterAdmins()
      if $scope.database
        $scope.selectedDatabase = $scope.database
        $scope.getDatabaseUsers()

      $location.search({})
    , (response) ->
      $scope.alertFailure("Couldn't authenticate user: #{response.responseText}")

  $scope.authenticateAsDatabaseAdmin = () ->
    window.influxdb = new InfluxDB
      host: $scope.host
      port: $scope.port
      username: $scope.username
      password: $scope.password
      database: $scope.database
      ssl: $scope.ssl

    $q.when(window.influxdb.authenticateDatabaseUser($scope.database)).then (response) ->
      $scope.authenticated = true
      $scope.isDatabaseAdmin = true
      $scope.isClusterAdmin = false
      $scope.selectedPane = "databases"
      $scope.selectedSubPane = "users"
      $scope.selectedDatabase = $scope.database
      # $scope.setCurrentInterface("default")
      $location.search({})
      $scope.storeAuthenticatedCredentials()
      $scope.getInterfaces()
      $scope.getDatabaseUsers()

    , (response) ->
      $scope.authenticateAsClusterAdmin()

  $scope.storeAuthenticatedCredentials = () ->
    $cookieStore.put("username", $scope.username)
    $cookieStore.put("password", $scope.password)
    $cookieStore.put("database", $scope.database)
    $cookieStore.put("host", $scope.host)
    $cookieStore.put("port", $scope.port)
    $cookieStore.put("ssl", $scope.ssl)

  $scope.getDatabases = () ->
    $q.when(window.influxdb.getDatabases()).then (response) ->
      $scope.databases = response
      $scope.shardSpaces = []
      $scope.addShardSpace()


  $scope.getClusterAdmins = () ->
    $q.when(window.influxdb.getClusterAdmins()).then (response) ->
      $scope.admins = response

  $scope.deleteClusterAdmin = (name) ->
    if $scope.username == name
      $scope.alertFailure("You can't delete the cluster admin you're currently logged in as.")
    else
      $q.when(window.influxdb.deleteClusterAdmin(name)).then (response) ->
        $scope.alertSuccess("Successfully deleted cluster admin: #{name}")
        $scope.getClusterAdmins()
      , (response) ->
        $scope.alertFailure("Failed to deleted cluster admin: #{response.responseText}")

  $scope.createClusterAdmin = () ->
    $q.when(window.influxdb.createClusterAdmin($scope.newAdminUsername, $scope.newAdminPassword)).then (response) ->
      $scope.alertSuccess("Successfully created user: #{$scope.newAdminUsername}")
      $scope.newAdminUsername = null
      $scope.newAdminPassword = null
      $scope.getClusterAdmins()
    , (response) ->
      $scope.alertFailure("Failed to create user: #{response.responseText}")

  $scope.addShardSpace = () ->
    $scope.shardSpaces.push
      name: "default"
      regEx: "/.*/"
      retentionPolicy: "inf"
      shardDuration: "7d"
      replicationFactor: 1
      split: 1

  $scope.removeShardSpace = (index) ->
    $scope.shardSpaces.splice(index,1)
    if $scope.shardSpaces.length == 0
      $scope.addShardSpace()

  $scope.createDatabase = () ->
    data = {spaces: $scope.shardSpaces}

    $q.when(window.influxdb.createDatabaseConfig($scope.newDatabaseName, data)).then (response) ->
      $scope.alertSuccess("Successfully created database: #{$scope.newDatabaseName}")
      $scope.newDatabaseName = null
      $scope.getDatabases()
    , (response) ->
      $scope.alertFailure("Failed to create database: #{response.responseText}")

  $scope.createDatabaseUser = () ->
    $q.when(window.influxdb.createUser($scope.selectedDatabase, $scope.newDbUser.username, $scope.newDbUser.password)).then (response) ->
      $scope.alertSuccess("Successfully created user: #{$scope.newDbUser.username}")
      data = {admin: $scope.newDbUser.isAdmin}
      window.influxdb.updateDatabaseUser($scope.selectedDatabase, $scope.newDbUser.username, data)
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

  $scope.getDatabaseUser = () ->
    $q.when(window.influxdb.getDatabaseUser($scope.selectedDatabase, $scope.selectedDatabaseUser)).then (response) ->
      $scope.databaseUser = response

  $scope.showSelectedDatabase = () ->
    $scope.selectedPane = 'databases'
    $scope.selectedSubPane = 'users'
    $scope.selectedDatabaseUser = null
    $scope.getDatabaseUsers()

  $scope.showDatabases = () ->
    $scope.getDatabases()
    $scope.selectedPane = 'databases'
    $scope.selectedSubPane = 'users'
    $scope.selectedDatabase = null
    $scope.selectedDatabaseUser = null

  $scope.showDatabase = (database) ->
    $scope.selectedDatabase = database.name
    $scope.selectedDatabaseUser = null
    $scope.getDatabaseUsers()

  $scope.showDatabaseUsers = () ->
    $scope.selectedDatabaseUser = null
    $scope.selectedSubPane = "users"
    $scope.getDatabaseUsers()

  $scope.getContinuousQueries = () ->
    $q.when(window.influxdb.getContinuousQueries($scope.selectedDatabase)).then (response) ->
      $scope.continuousQueries = response

  $scope.showContinuousQueries = () ->
    $scope.selectedDatabaseUser = null
    $scope.selectedSubPane = "continuousQueries"
    $scope.getContinuousQueries()

  $scope.deleteContinuousQuery = (continuousQuery) ->
    $q.when(window.influxdb.deleteContinuousQuery($scope.selectedDatabase, continuousQuery.id)).then (response) ->
      $scope.alertSuccess("Successfully deleted conitinuous query: '#{continuousQuery.id}'")
      $scope.getContinuousQueries()
    , (response) ->
      $scope.alertFailure("Failed to delete continuous query: #{response.responseText}")

  $scope.showDbSettings = () ->
    $scope.selectedDatabaseUser = null
    $scope.selectedSubPane = "settings"
    $scope.getDatabaseUsers()
    $scope.getContinuousQueries()

  $scope.showClusterAdmins = () ->
    $scope.getClusterAdmins()
    $scope.selectedPane = "admins"
    $scope.selectedClusterAdmin = null

  $scope.showClusterConfiguration = () ->
    $scope.getClusterServers()
    $scope.getClusterShards()
    $scope.getClusterShardSpaces()
    $scope.selectedPane = "cluster"

  $scope.getClusterServers = () ->
    $q.when(window.influxdb.getClusterServers()).then (response) ->
      $scope.clusterServers = response

  $scope.getClusterShards = () ->
    $q.when(window.influxdb.getClusterShards()).then (response) ->
      $scope.clusterShards = response

  $scope.getClusterShardSpaces = () ->
    $q.when(window.influxdb.getClusterShardSpaces()).then (response) ->
      $scope.clusterShardSpaces = response

  $scope.deleteClusterShard = (clusterShard) ->
    $q.when(window.influxdb.deleteClusterShard(clusterShard.id, clusterShard.serverIds)).then (response) ->
      $scope.alertSuccess("Successfully deleted shard: '#{clusterShard.id}'")
      $scope.getClusterShards()
    , (response) ->
      $scope.alertFailure("Failed to delete shard: #{response.responseText}")

  $scope.showClusterAdmin = (clusterAdmin) ->
    $scope.selectedClusterAdmin = clusterAdmin.name

  $scope.showDatabaseUser = (databaseUser) ->
    $scope.selectedDatabaseUser = databaseUser.name
    $scope.getDatabaseUser()

  $scope.changeDbUserPassword = () ->
    if $scope.dbUserPassword != $scope.dbUserPasswordConfirmation
      $scope.alertFailure("Sorry, the passwords don't match.")
    else if $scope.dbUserPassword == null or $scope.dbUserPassword == ""
      $scope.alertFailure("Sorry, passwords cannot be blank.")
    else
      data = {password: $scope.dbUserPassword}
      $q.when(window.influxdb.updateDatabaseUser($scope.selectedDatabase, $scope.selectedDatabaseUser, data)).then (response) ->
        $scope.alertSuccess("Successfully changed password for '#{$scope.selectedDatabaseUser}'")
        $scope.dbUserPassword = null
        $scope.dbUserPasswordConfirmation = null
      , (response) ->
        $scope.alertFailure("Failed to change password for user: #{response.responseText}")

  $scope.changeClusterAdminPassword = () ->
    if $scope.clusterAdminPassword != $scope.clusterAdminPasswordConfirmation
      $scope.alertFailure("Sorry, the passwords don't match.")
    else if $scope.clusterAdminPassword == null or $scope.clusterAdminPassword == ""
      $scope.alertFailure("Sorry, passwords cannot be blank.")
    else
      data = {password: $scope.clusterAdminPassword}
      $q.when(window.influxdb.updateClusterAdmin($scope.selectedClusterAdmin, data)).then (response) ->
        $scope.alertSuccess("Successfully changed password for '#{$scope.selectedClusterAdmin}'")
        $scope.clusterAdminPassword = null
        $scope.clusterAdminPasswordConfirmation = null
      , (response) ->
        $scope.alertFailure("Failed to change password for cluster admin: #{response.responseText}")

  $scope.updateDatabaseUser = () ->
    data = {admin: $scope.databaseUser.isAdmin}
    $q.when(window.influxdb.updateDatabaseUser($scope.selectedDatabase, $scope.selectedDatabaseUser, data)).then (response) ->
      $scope.alertSuccess("Successfully updated database user '#{$scope.selectedDatabaseUser}'")
      $scope.getDatabaseUsers()
    , (response) ->
      $scope.alertFailure("Failed to update database user: #{response.responseText}")

  $scope.deleteDatabaseUser = (username) ->
    $q.when(window.influxdb.deleteDatabaseUser($scope.selectedDatabase, username)).then (response) ->
      $scope.alertSuccess("Successfully delete user: #{username}")
      $scope.getDatabaseUsers()
    , (response) ->
      $scope.alertFailure("Failed to delete user: #{response.responseText}")
]

adminApp.directive "ngConfirmClick", [ ->
  priority: -1
  restrict: "A"
  link: (scope, element, attrs) ->
    element.bind "click", (e) ->
      message = attrs.ngConfirmClick
      if message and not confirm(message)
        e.stopImmediatePropagation()
        e.preventDefault()
]

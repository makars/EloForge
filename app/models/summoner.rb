class Summoner < ActiveRecord::Base
	has_many :games
	def self.update(params)
    	# Check if name is already connected to a number.
    	summName = params['search']
    	server = params['servers']['server']
    	@internalName = summName.to_s.downcase.delete(' ')
    	@summoner = Summoner.find_by internalName: @internalName

  		if (@summoner == nil)
		# Run only if # is not already stored or it is out of date
			call = RiotApiCall.new(:server => server, :summName => @internalName)
			call.getSummonerByName
			#logger.debug "MODEL LEVEL: #{call.inspect}"
			@responseHash = call.response

			@summoner = Summoner.find_by summonerId: @responseHash[call.summName]['id']
			if @summoner != nil
				#summoner is already stored under a different name, update the name
				@summoner.internalName = @internalName
				@summoner.formattedName = @responseHash[call.summName]['name']
				@summoner.lastUpdated = Time.now.to_i
				@summoner.save
			else
				summId = @responseHash[call.summName]['id']
				@summoner = Summoner.new(:formattedName => @responseHash[call.summName]['name'], :internalName => call.summName, :summonerId => summId, :lastUpdated => (Time.now - ENV['UPDATE_AFTER_SECONDS'].to_i) )
				@summoner.save
			end
		elsif (Time.now.to_i - @summoner.lastUpdated.to_i > 900)
			call = RiotApiCall.new(:server => server, :summName => @internalName)
			call.getSummonerByName
			resp_hash = call.response
			@summoner.formattedName = resp_hash[call.summName]['name']
			@summoner.internalName = @internalName
			@summoner.save
		end
		
		if (Time.now.to_i - @summoner.lastUpdated.to_i) > 900
			#If the summoner is due for a game update, update the games.
			request2 = "https://" + server.downcase + ".api.pvp.net/api/lol/" + server.downcase + "/" + ENV['MATCH_HISTORY_VERSION'].to_s + "/matchhistory/" + @summoner.summonerId.to_s + "?api_key=" + ENV['RIOT_API_KEY'].to_s
			call = RiotApiCall.new(:server => server.downcase, :api_call => request2, :summName => @internalName)
			call.getMatchHistoryById
			resp = call.response
			logger.info "#{resp}"
			match = resp['matches'].last
			#query match['matchId']
			## https://na.api.pvp.net/api/lol/na/v2.2/match/1878587595?includeTimeline=true&api_key=f41ed978-fff5-4ae3-b1df-7e9131627fee
			match_request = "https://" + server.downcase + ".api.pvp.net/api/lol/" + server.downcase + "/" + ENV['MATCH_VERSION'].to_s + "/match/" + match['matchId'].to_s + "?includeTimeline=true&api_key=" + ENV['RIOT_API_KEY'].to_s
			match_call = RiotApiCall.new(:server => server.downcase, :api_call => match_request)
			match_call.getMatchByMatchId
			match_resp = match_call.response
			@lame = Game.find_by(gameId: match_resp["matchId"], summoner_id: @summoner.id)
			
			logger.debug "LAST: #{@lame.inspect}"
			if @lame == nil
				game = Game.new(:gameData => match_resp, :gameId => match_resp['matchId'], :summoner_id => @summoner.id)
				game.save
				logger.info 'Game Updated'
				@summoner.lastGameId = game.gameId
			else
				logger.info 'No New Game'
			end
			#resp['matches'].each do |match|
			#	if (Game.find_by gameId: match['matchId'] ) == nil
			#		game = Game.new(:gameData => resp, :gameId => match['matchId'], :summoner_id => @summoner.id)
			#		game.save
			#		@summoner.lastGameId = game.gameId
			#	end
			#end		
			@summoner.lastUpdated = Time.now.to_i
			@summoner.save
			#logger.info "Game #{game.gameId} saved."
		end


		return @summoner
	end
end

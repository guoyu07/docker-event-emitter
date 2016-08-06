module Main where

import Docker.Event.Emitter

import Data.Conduit (($$))
import Network.HTTP.Client
import Network.HTTP.Client.Conduit (bodyReaderSource)
import Network.HTTP.Simple
import Options.Applicative hiding (choice)

appParser :: Parser App
appParser = App <$> (option auto
                       ( long "backend"
                      <> short 'b'
                      <> metavar "BACKEND"
                      <> help "Backend type: redis | web"
                      <> completeWith ["redis", "web"]))
                <*> (strOption
                       ( long "endpoint"
                      <> short 'e'
                      <> metavar "ENDPOINT"
                      <> help "Redis: hostname:port | web: full url"))

-- | Parses the options to extract the correct 'dispatcher', and then connects to the docker daemon.
main :: IO ()
main = do
    app <- execParser opts
    let publisher = getPublisher app
    manager <- unixSocketManager
    request <- parseRequest "http://localhost/events"
    let request' = setRequestManager manager request
    withResponse request manager $ \response -> do
        let loop = do
                bodyReaderSource (responseBody response) $$ newEvent publisher
                loop
        loop
    where
        opts = info (helper <*> appParser)
           ( fullDesc
          <> header "Docker Event Emitter - relay docker events to somewhere else"
          <> progDesc "Emit docker events to a subscriber such as Redis or a RESTful endpoint.")

        getPublisher app = case listener app of
            Redis -> publishToRedis $ endpoint app
            Web   -> publishToRest  $ endpoint app

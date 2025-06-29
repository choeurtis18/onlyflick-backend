package logger

import (
	"go.uber.org/zap"
	"go.uber.org/zap/zapcore"
)

var Log *zap.Logger

// InitLogger initialise un logger structuré avec zap
func InitLogger(isDevelopment bool) {
	var config zap.Config

	if isDevelopment {
		config = zap.NewDevelopmentConfig()
	} else {
		config = zap.NewProductionConfig()
		config.EncoderConfig.TimeKey = "timestamp"
		config.EncoderConfig.EncodeTime = zapcore.ISO8601TimeEncoder
	}

	var err error
	Log, err = config.Build()
	if err != nil {
		panic("Impossible d'initialiser le logger: " + err.Error())
	}

	Log.Info("Logger initialisé avec succès",
		zap.Bool("development_mode", isDevelopment),
	)
}

// GetRequestLogger crée un logger pour une requête HTTP avec des champs personnalisés
func GetRequestLogger(requestID string, userID int64, path string) *zap.Logger {
	return Log.With(
		zap.String("request_id", requestID),
		zap.Int64("user_id", userID),
		zap.String("path", path),
	)
}

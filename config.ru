ENV['DATABASE_URL'] ||= "postgresql://sabineblanc:sabineblanc@localhost:5432/sabineblanc"
require './sabine-blanc'
run SabineBlanc

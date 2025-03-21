idf_component_register(SRCS "BLEBackend.cpp" "TelometerImpl.cpp" "gatt.cpp" "gap.cpp"
			           INCLUDE_DIRS .
					   REQUIRES driver bt nvs_flash)
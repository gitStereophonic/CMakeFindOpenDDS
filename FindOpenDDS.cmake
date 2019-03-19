# This module attempts to finds OpenDDS.
# 
# It defines the following variables:
# 
# * OpenDDS_FOUND
# * OpenDDS_INCLUDE_DIRS
# * OpenDDS_LIBRARY_DIRS
# * OpenDDS_LIBRARIES
# * OpenDDS_TAO_IDL_EXECUTABLE
# * OpenDDS_IDL_EXECUTABLE
# * OpenDDS_ROOT_DIR
# * OpenDDS_FLAGS                
# * OpenDDS_TAO_FLAGS                
#
# Debug:
# 	set(CMAKE_VERBOSE_MAKEFILE on)

function(FindOpenDDS)
	# Find IDL compilers
	find_program(TAO_IDL "tao_idl")
	find_program(OpenDDS_IDL "opendds_idl")
	if (TAO_IDL AND OpenDDS_IDL)
		# Export variables
		set(OpenDDS_IDL_EXECUTABLE ${OpenDDS_IDL} PARENT_SCOPE)
		set(OpenDDS_TAO_IDL_EXECUTABLE ${TAO_IDL} PARENT_SCOPE)
		set(TOOL_FOUND TRUE)

		if(NOT OpenDDS_FIND_QUIETLY)
			message(STATUS "OpenDDS found")
		endif()

	else(OPENDDS_IDL_COMMAND_)
		set(TOOL_FOUND FALSE)

		if(NOT OpenDDS_FIND_QUIETLY)
			message(FATAL_ERROR "OpenDDS not found")
		endif()
	endif()
	
	# Export variables
	set(OpenDDS_FOUND ${TOOL_FOUND} PARENT_SCOPE)
	
	# Show found tools dirs
	message(STATUS "Env OpenDDS Root: $ENV{DDS_ROOT}")
	message(STATUS "Env Ace Root: $ENV{ACE_ROOT}")
	message(STATUS "Env TAO Root: $ENV{TAO_ROOT}")
	
	if (TOOL_FOUND)
		# Export variables
		set(TAO_FLAGS "")
		list(APPEND TAO_FLAGS "-I$ENV{TAO_ROOT}")
		list(APPEND TAO_FLAGS "-I$ENV{DDS_ROOT}")
		list(APPEND TAO_FLAGS "-I.")
		list(APPEND TAO_FLAGS "-Wb,pre_include=ace/pre.h")
		list(APPEND TAO_FLAGS "-Wb,post_include=ace/post.h")
		list(APPEND TAO_FLAGS "-Sa")
		list(APPEND TAO_FLAGS "-St")

		set(OpenDDS_FLAGS "")
		list(APPEND OpenDDS_FLAGS "-Lspcpp")
		list(APPEND OpenDDS_FLAGS "-I$ENV{DDS_ROOT}")
		list(APPEND OpenDDS_FLAGS "-I.")
		list(APPEND OpenDDS_FLAGS "-Sa")
		list(APPEND OpenDDS_FLAGS "-St")


		set(OpenDDS_FLAGS "${OpenDDS_FLAGS}" PARENT_SCOPE)
		set(OpenDDS_TAO_FLAGS "${TAO_FLAGS}" PARENT_SCOPE)
		set(OpenDDS_ROOT_DIR $ENV{DDS_ROOT} PARENT_SCOPE)

		set(include_dirs "")
		list(APPEND include_dirs $ENV{DDS_ROOT})
		list(APPEND include_dirs $ENV{ACE_ROOT})
		list(APPEND include_dirs $ENV{TAO_ROOT})
		set(OpenDDS_INCLUDE_DIRS ${include_dirs} PARENT_SCOPE)


		set(library_dirs "")
		list(APPEND library_dirs $ENV{DDS_ROOT}/lib)
		list(APPEND library_dirs $ENV{ACE_ROOT}/lib)
		list(APPEND library_dirs $ENV{TAO_ROOT}/lib)
		set(OpenDDS_LIBRARY_DIRS ${library_dirs} PARENT_SCOPE)

		set(all_libs "")
		foreach(lib_dir ${library_dirs})
			file(GLOB _libs "${lib_dir}/*.so")
			foreach(_lib ${_libs})
				list(APPEND all_libs "${_lib}")
			endforeach(_lib)
		endforeach(lib_dir)
		set(OpenDDS_LIBRARIES ${all_libs} PARENT_SCOPE)

	endif()

endfunction()

# Provides following function to compile idl files:
# 	DDSCompileIdl(<input-variable;file-list> <output-variable;GENERATED_SRC_FILES>
#					<output-variable;GENERATED_HDR_FILES> )
function(DDSCompileIdl IDL_FILENAMES GENERATED_SRC_FILES GENERATED_HDR_FILES)
	# ERROR if OpenDDS did not found
	if (NOT OpenDDS_FOUND)
		message(FATAL_ERROR "OpenDDS not found")
	endif()

	set(RES_CPP "")
	set(RES_HPP "")
	set(IDLS_GENERATED_DIR "${CMAKE_CURRENT_BINARY_DIR}/bin/idl_generated"
		CACHE INTERNAL "" FORCE)
	foreach(filename ${IDL_FILENAMES})
		# Split filepath
		get_filename_component(filename_n ${filename} NAME)
		get_filename_component(filename_we ${filename} NAME_WE)

		set(WORKING_FILE "${IDLS_GENERATED_DIR}/${filename_n}")

		message(STATUS "WORKING IDL FILE: ${WORKING_FILE}")

		# Copy .idl file to build directory to work on it
		configure_file(${filename} ${WORKING_FILE} COPYONLY)

		# First step:
		# 	The OpenDDS IDL is first processed by the TAO IDL compiler.
		
		# Construct tao_idl result filenames
		set(IDL_C_CPP "${IDLS_GENERATED_DIR}/${filename_we}C.cpp")
		set(IDL_C_H   "${IDLS_GENERATED_DIR}/${filename_we}C.h")
		set(IDL_C_INL "${IDLS_GENERATED_DIR}/${filename_we}C.inl")
		set(IDL_S_CPP "${IDLS_GENERATED_DIR}/${filename_we}S.cpp")
		set(IDL_S_H   "${IDLS_GENERATED_DIR}/${filename_we}S.h")

		# Append result filenames
		list(APPEND RES_CPP ${IDL_C_CPP})
		list(APPEND RES_CPP ${IDL_S_CPP})
		list(APPEND RES_HPP ${IDL_C_H})
		list(APPEND RES_HPP ${IDL_C_INL})
		list(APPEND RES_HPP ${IDL_S_H})

		# Compile tao_idl
		add_custom_target(
			First_IDL_Compilation
			ALL
			DEPENDS ${IDL_C_CPP} ${IDL_C_H} ${IDL_C_INL} ${IDL_S_CPP} ${IDL_S_H}
		)
		add_custom_command(
			OUTPUT ${IDL_C_CPP} ${IDL_C_H} ${IDL_C_INL} ${IDL_S_CPP} ${IDL_S_H}
			DEPENDS ${WORKING_FILE}
			COMMAND ${OpenDDS_TAO_IDL_EXECUTABLE}
			ARGS ${OpenDDS_TAO_FLAGS} ${WORKING_FILE}
			WORKING_DIRECTORY ${IDLS_GENERATED_DIR}
			COMMENT "Compiling first idl template(s)"
		)

		# Second step:
		# 	Process the IDL file with the OpenDDS IDL compiler to generate the
		# 	serialization and key support code that OpenDDS requires to marshal
		#	and demarshal the Message, as well as the type support code for
		#	the data readers and writers.

		# Construct opendds_idl result filenames
		set(TYPE_SUPPORT_IDL "${IDLS_GENERATED_DIR}/${filename_we}TypeSupport.idl")
		set(TYPE_SUPPORT_H   "${IDLS_GENERATED_DIR}/${filename_we}TypeSupportImpl.h")
		set(TYPE_SUPPORT_CPP "${IDLS_GENERATED_DIR}/${filename_we}TypeSupportImpl.cpp")
		# Append result filenames
		list(APPEND RES_CPP ${TYPE_SUPPORT_CPP})
		list(APPEND RES_HPP ${TYPE_SUPPORT_H})
		list(APPEND RES_HPP ${TYPE_SUPPORT_IDL})

		set(res "${res};${TYPE_SUPPORT_IDL};${TYPE_SUPPORT_H};${TYPE_SUPPORT_CPP}")

		# Compile opendds_idl
		add_custom_target(
			OpenDDS_IDL_Compilation
			ALL
			DEPENDS ${TYPE_SUPPORT_IDL} ${TYPE_SUPPORT_H} ${TYPE_SUPPORT_CPP}
		)
		add_custom_command(
			OUTPUT ${TYPE_SUPPORT_IDL} ${TYPE_SUPPORT_H} ${TYPE_SUPPORT_CPP}
			DEPENDS ${WORKING_FILE} ${IDL_C_CPP} ${IDL_C_H} ${IDL_C_INL} ${IDL_S_CPP} ${IDL_S_H}
			COMMAND ${OpenDDS_IDL_EXECUTABLE} 
			ARGS ${OpenDDS_FLAGS} ${WORKING_FILE}
			WORKING_DIRECTORY ${IDLS_GENERATED_DIR}
		)

		# Third step:
		# 	The generated IDL file should itself be compiled with
		# 	the TAO IDL compiler to generate stubs and skeletons

		# Construct tao_idl result filenames
		set(TYPE_SUPPORT_IDL_C_CPP "${IDLS_GENERATED_DIR}/${filename_we}TypeSupportC.cpp")
		set(TYPE_SUPPORT_IDL_C_H   "${IDLS_GENERATED_DIR}/${filename_we}TypeSupportC.h")
		set(TYPE_SUPPORT_IDL_C_INL "${IDLS_GENERATED_DIR}/${filename_we}TypeSupportC.inl")
		set(TYPE_SUPPORT_IDL_S_CPP "${IDLS_GENERATED_DIR}/${filename_we}TypeSupportS.cpp")
		set(TYPE_SUPPORT_IDL_S_H   "${IDLS_GENERATED_DIR}/${filename_we}TypeSupportS.h")

		# Append result filenames
		list(APPEND RES_CPP ${TYPE_SUPPORT_IDL_C_CPP})
		list(APPEND RES_CPP ${TYPE_SUPPORT_IDL_S_CPP})
		list(APPEND RES_HPP ${TYPE_SUPPORT_IDL_C_H})
		list(APPEND RES_HPP ${TYPE_SUPPORT_IDL_C_INL})
		list(APPEND RES_HPP ${TYPE_SUPPORT_IDL_S_H})

		# Compile tao_idl
		add_custom_target(
			Second_IDL_Compilation
			ALL
			DEPENDS ${TYPE_SUPPORT_IDL_C_CPP} ${TYPE_SUPPORT_IDL_C_H} ${TYPE_SUPPORT_IDL_C_INL} ${TYPE_SUPPORT_IDL_S_CPP} ${TYPE_SUPPORT_IDL_S_H}
		)
		add_custom_command(
			OUTPUT ${TYPE_SUPPORT_IDL_C_CPP} ${TYPE_SUPPORT_IDL_C_H} ${TYPE_SUPPORT_IDL_C_INL} ${TYPE_SUPPORT_IDL_S_CPP} ${TYPE_SUPPORT_IDL_S_H}
			DEPENDS ${TYPE_SUPPORT_IDL}
			COMMAND ${OpenDDS_TAO_IDL_EXECUTABLE} 
			ARGS ${OpenDDS_TAO_FLAGS} ${TYPE_SUPPORT_IDL} 
			WORKING_DIRECTORY ${IDLS_GENERATED_DIR}
		)

	endforeach(filename)

	# Output result filenames
	set(${GENERATED_SRC_FILES} ${RES_CPP} PARENT_SCOPE)
	set(${GENERATED_HDR_FILES} ${RES_HPP} PARENT_SCOPE)

endfunction()

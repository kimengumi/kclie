<?php
/*
* Kimengumi Command Line Interface Environnement
*
* Minimalistic SQL Library
* mostly useful to quick write php CLI batchs.
*
* Copyright 2021 Antonio Rossetti (https://www.kimengumi.fr)
*
* Licensed under the EUPL, Version 1.1 or – as soon they will be approved by
* the European Commission - subsequent versions of the EUPL (the "Licence");
* You may not use this work except in compliance with the Licence.
* You may obtain a copy of the Licence at:
*
* https://joinup.ec.europa.eu/software/page/eupl
*
* Unless required by applicable law or agreed to in writing, software
* distributed under the Licence is distributed on an "AS IS" basis,
* WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
* See the Licence for the specific language governing permissions and
* limitations under the Licence.
*/

class kSql {

	/**
	 * @var mysqli null
	 */
	private static $db = null;

	/**
	 * Connect to Mysql
	 */
	public static function init() {
		//@todo manage .my.cnf
		self::$db = new mysqli( KCLIE_KSQL_HOST, KCLIE_KSQL_USER, KCLIE_KSQL_PASS, KCLIE_KSQL_DB );
	}

	/**
	 * @param $query
	 *
	 * @return mixed|bool
	 */
	public static function getFirst( $query ) {

		if ( ! self::$db ) {
			self::init();
		}

		/** @var \mysqli_result $res */
		if ( is_bool( $res = self::$db->query( $query ) ) ) {
			return $res ?? die( "SQL ERR " . self::$db->error . "\n" . $query . "\n" );
		} else {
			while ( $row = $res->fetch_array() ) {
				foreach ( $row as $value ) {
					return $value;
				}
			}
		}

		return false;
	}

	/**
	 * @param $query
	 *
	 * @return array|bool
	 */
	public static function getAll( $query ) {

		if ( ! self::$db ) {
			self::init();
		}

		/** @var \mysqli_result $res */
		if ( is_bool( $res = self::$db->query( $query ) ) ) {
			return $res ?? die( "SQL ERR " . self::$db->error . "\n" . $query . "\n" );
		} else {
			return $res->fetch_all(MYSQLI_ASSOC);
		}


	}


	/**
	 * @param $query
	 *
	 * @return bool|mixed
	 */
	public static function write( $query ) {

		if ( ! self::$db ) {
			self::init();
		}

		/** @var mysqli_result $res */
		if ( ! self::$db->query( $query ) ) {
			die( "SQL ERR " . self::$db->error . "\n" . $query . "\n" );
		}

		return true;
	}
}
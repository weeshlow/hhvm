<?php
	require('connect.inc');
	if (!$link = my_mysqli_connect($host, $user, $passwd, $db, $port, $socket))
		printf("[001] [%d] %s\n", mysqli_connect_errno(), mysqli_connect_error());

	if (!$res = mysqli_query($link, "SHOW GLOBAL VARIABLES LIKE 'max_allowed_packet'"))
		printf("[002] [%d] %s\n", mysqli_errno($link), mysqli_error($link));

	if (!$row = mysqli_fetch_assoc($res))
		printf("[003] [%d] %s\n", mysqli_errno($link), mysqli_error($link));

	mysqli_free_result($res);

	if (0 === ($org_max_allowed_packet = (int)$row['Value']))
		printf("[004] Cannot determine max_allowed_packet size and/or bogus max_allowed_packet setting used.\n");

	$max_len = pow(2, 24);
	if ($org_max_allowed_packet < $max_len) {
		if (!mysqli_query($link, "SET GLOBAL max_allowed_packet = " . ($max_len + 100))) {
			if (1227 == mysqli_errno($link)) {
				/* [1227] Access denied; you need the SUPER privilege for this operation */
				print "done!";
				exit(0);
			} else {
				printf("[005] [%d] %s\n", mysqli_errno($link), mysqli_error($link));
			}
		}
	}
	mysqli_close($link);
	if (!$link = my_mysqli_connect($host, $user, $passwd, $db, $port, $socket))
		printf("[006] [%d] %s\n", mysqli_connect_errno(), mysqli_connect_error());

	if (!mysqli_query($link, "SET NAMES 'latin1'"))
		printf("[007] [%d] %s\n", mysqli_connect_errno(), mysqli_connect_error());

	if (!$res = mysqli_query($link, "SHOW GLOBAL VARIABLES LIKE 'max_allowed_packet'"))
		printf("[008] [%d] %s\n", mysqli_errno($link), mysqli_error($link));

	if (!$row = mysqli_fetch_assoc($res))
		printf("[009] [%d] %s\n", mysqli_errno($link), mysqli_error($link));

	mysqli_free_result($res);

	if (0 === ($max_allowed_packet = (int)$row['Value']))
		printf("[010] Cannot determine max_allowed_packet size and/or bogus max_allowed_packet setting used.\n");

	$max_len = pow(2, 24);
	if ($max_allowed_packet < $max_len) {
		printf("[011] Failed to change max_allowed_packet");
	}

	if (!mysqli_query($link, "CREATE TABLE test_mysqli_insert_packet_overflow_table_1(col_blob LONGBLOB) ENGINE=" . $engine))
		printf("[012] [%d] %s\n", mysqli_errno($link), mysqli_error($link));

	$query_prefix = "INSERT INTO test_mysqli_insert_packet_overflow_table_1(col_blob) VALUES ('";
	$query_postfix = "')";
	$query_len = strlen($query_prefix) + strlen($query_postfix);
	$com_query_len = 2;


	$blob = str_repeat('a', $max_len - $com_query_len - $query_len);
	$query = sprintf("%s%s%s", $query_prefix, $blob, $query_postfix);

	if (!mysqli_query($link, $query))
		printf("[013] max_allowed_packet = %d, strlen(query) = %d, [%d] %s\n", $max_allowed_packet, strlen($query), mysqli_errno($link), mysqli_error($link));

	if (!$res = mysqli_query($link, "SELECT col_blob FROM test_mysqli_insert_packet_overflow_table_1"))
		printf("[014] [%d] %s\n", mysqli_errno($link), mysqli_error($link));

	if (!$row = mysqli_fetch_assoc($res)) {
		printf("[015] [%d] %s\n", mysqli_errno($link), mysqli_error($link));
	} else {
		if ($row['col_blob'] != $blob) {
			printf("[016] Blob seems wrong, dumping data\n");
			var_dump(strlen($row['col_blob']));
			var_dump(strlen($blob));
		}
		mysqli_free_result($res);
	}

	if (!mysqli_query($link, "SET GLOBAL max_allowed_packet = " . $org_max_allowed_packet))
		if (1227 != mysqli_errno($link))
			printf("[017] [%d] %s\n", mysqli_errno($link), mysqli_error($link));

	mysqli_close($link);

	print "done!";
?>
<?php error_reporting(0); ?>
<?php
	$test_table_name = 'test_mysqli_insert_packet_overflow_table_1'; require_once("clean_table.inc");
?>
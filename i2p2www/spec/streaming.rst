================================
Streaming Protocol Specification
================================
.. meta::
    :category: Protocols
    :lastupdated: 2023-01
    :accuratefor: 0.9.57

.. contents::


Overview
========

See [STREAMING]_ for an overview of the Streaming protocol.


.. _versions:

Protocol Versions
=================

The streaming protocol does not include a version field.
The versions listed below are for Java I2P.
Implementations and actual crypto support may vary.
There is no way to determine if the far-end supports any particular version or feature.
The table below is for general guidance as to the release dates for various features.

The features listed below are for the protocol itself.
Various options for configuration are documented in [STREAMING]_ along with the
Java I2P version in which they were implemented.


==============  ================================================================
Router Version  Streaming Features
==============  ================================================================
   0.9.39       OFFLINE_SIGNATURE option

   0.9.36       I2CP protocol number enforced

   0.9.20       FROM_INCLUDED no longer required in RESET

   0.9.18       PINGs and PONGs may include a payload

   0.9.15       EdDSA Ed25519 sig type

   0.9.12       ECDSA P-256, P-384, and P-521 sig types

   0.9.11       Variable-length signatures

   0.7.1        Protocol numbers defined in I2CP

==============  ================================================================


Protocol Specification
======================

Packet Format
-------------

The format of a single packet in the streaming protocol is shown below.
The minimum header size, without NACKs or option data, is 22 bytes.

There is no length field in the streaming protocol.
Framing is provided by the lower layers - I2CP and I2NP.


.. raw:: html

  {% highlight lang='dataspec' %}
+----+----+----+----+----+----+----+----+
  | send Stream ID    | rcv Stream ID     |
  +----+----+----+----+----+----+----+----+
  | sequence  Num     | ack Through       |
  +----+----+----+----+----+----+----+----+
  | nc |  nc*4 bytes of NACKs (optional)
  +----+----+----+----+----+----+----+----+
       | rd |  flags  | opt size| opt data
  +----+----+----+----+----+----+----+----+
     ...  (optional, see below)           |
  +----+----+----+----+----+----+----+----+
  |   payload ...
  +----+----+----+-//



  sendStreamId :: 4 byte `Integer`
                  Random number selected by the packet recipient before sending
                  the first SYN reply packet and constant for the life of the
                  connection, greater than zero. 0 in the SYN message sent by the connection
                  originator, and in subsequent messages, until a SYN reply is
                  received, containing the peer's stream ID.

  receiveStreamId :: 4 byte `Integer`
                     Random number selected by the packet originator before
                     sending the first SYN packet and constant for the life of
                     the connection, greater than zero.
                     May be 0 if unknown, for example in a RESET packet.

  sequenceNum :: 4 byte `Integer`
                 The sequence for this message, starting at 0 in the SYN
                 message, and incremented by 1 in each message except for plain
                 ACKs and retransmissions. If the sequenceNum is 0 and the SYN
                 flag is not set, this is a plain ACK packet that should not be
                 ACKed.

  ackThrough :: 4 byte `Integer`
                The highest packet sequence number that was received on the
                $receiveStreamId. This field is ignored on the initial
                connection packet (where $receiveStreamId is the unknown id) or
                if the NO_ACK flag set. All packets up to and including this
                sequence number are ACKed, EXCEPT for those listed in NACKs
                below.

  NACK count :: 1 byte `Integer`
                The number of 4-byte NACKs in the next field

  NACKs :: $nc * 4 byte `Integer`s
           Sequence numbers less than ackThrough that are not yet received. Two
           NACKs of a packet is a request for a 'fast retransmit' of that packet.

  resendDelay :: 1 byte `Integer`
                 How long is the creator of this packet going to wait before
                 resending this packet (if it hasn't yet been ACKed).  The value
                 is seconds since the packet was created. Currently ignored on
                 receive.

  flags :: 2 byte value
           See below.

  option size :: 2 byte `Integer`
                 The number of bytes in the next field

  option data :: 0 or more bytes
                 As specified by the flags. See below.

  payload :: remaining packet size
{% endhighlight %}



Flags and Option Data Fields
----------------------------

The flags field above specifies some metadata about the packet, and in turn may
require certain additional data to be included.  The flags are as follows. Any
data structures specified must be added to the options area in the given order.

Bit order: 15....0 (15 is MSB)

=====  ========================  ============  ===============  ===============================================================
 Bit             Flag            Option Order    Option Data    Function
=====  ========================  ============  ===============  ===============================================================
  0    SYNCHRONIZE                    --             --         Similar to TCP SYN. Set in the initial packet and in the first
                                                                response. FROM_INCLUDED and SIGNATURE_INCLUDED must also be
                                                                set.

  1    CLOSE                          --             --         Similar to TCP FIN. If the response to a SYNCHRONIZE fits in a
                                                                single message, the response will contain both SYNCHRONIZE and
                                                                CLOSE. SIGNATURE_INCLUDED must also be set.

  2    RESET                          --             --         Abnormal close. SIGNATURE_INCLUDED must also be set. Prior to
                                                                release 0.9.20, due to a bug, FROM_INCLUDED must also be set.

  3    SIGNATURE_INCLUDED              5       variable length  Currently sent only with SYNCHRONIZE, CLOSE, and RESET, where
                                               [Signature]_     it is required, and with ECHO, where it is required for a
                                                                ping. The signature uses the Destination's [SigningPrivateKey]_
                                                                to sign the entire header and payload with the space in the
                                                                option data field for the signature being set to all zeroes.

                                                                Prior to release 0.9.11, the signature was always 40 bytes. As
                                                                of release 0.9.11, the signature may be variable-length, see
                                                                below for details.

  4    SIGNATURE_REQUESTED            --             --         Unused. Requests every packet in the other direction to have
                                                                SIGNATURE_INCLUDED

  5    FROM_INCLUDED                   2       387+ byte        Currently sent only with SYNCHRONIZE, where it is required, and
                                               [Destination]_   with ECHO, where it is required for a ping. Prior to release
                                                                0.9.20, due to a bug, must also be sent with RESET.

  6    DELAY_REQUESTED                 1       2 byte           Optional delay. How many milliseconds the sender of this packet
                                               [Integer]_       wants the recipient to wait before sending any more data. A
                                                                value greater than 60000 indicates choking. A value of 0
                                                                requests an immediate ack.

  7    MAX_PACKET_SIZE_INCLUDED        3       2 byte           The maximum length of the payload. Send with SYNCHRONIZE.
                                               [Integer]_

  8    PROFILE_INTERACTIVE            --             --         Unused or ignored; the interactive profile is unimplemented.

  9    ECHO                           --             --         Unused except by ping programs. If set, most other options are
                                                                ignored. See the streaming docs [STREAMING]_.

 10    NO_ACK                         --             --         This flag simply tells the recipient to ignore the ackThrough
                                                                field in the header. Currently set in the inital SYN packet,
                                                                otherwise the ackThrough field is always valid. Note that this
                                                                does not save any space, the ackThrough field is before the
                                                                flags and is always present.

 11    OFFLINE_SIGNATURE               4       variable length  Contains the offline signature section from LS2.
                                               [OfflineSig]_    See proposal 123 and the common structures specification.
                                                                FROM_INCLUDED must also be set.
                                                                Contains an [OfflineSig]_:
                                                                1) Expires timestamp (4 bytes, seconds since epoch, rolls over in 2106)
                                                                2) Transient sig type (2 bytes)
                                                                3) Transient [SigningPublicKey]_ (length as implied by sig type)
                                                                4) [Signature]_ of expires timestamp, transient sig type, and public key,
                                                                by the destination public key. Length of sig as implied by
                                                                by the destination public key sig type.

12-15  unused                                                   Set to zero for compatibility with future uses.
=====  ========================  ============  ===============  ===============================================================



Variable Length Signature Notes
```````````````````````````````
Prior to release 0.9.11, the signature in the option field was always 40 bytes.

As of release 0.9.11, the signature is variable length.  The Signature type and
length are inferred from the type of key used in the FROM_INCLUDED option and
the [Signature]_ documentation.

As of release 0.9.39, the OFFLINE_SIGNATURE option is supported.
If this option is present, the transient [SigningPublicKey]_
is used to verify any signed packets, and the
signature length and type are inferred from the transient [SigningPublicKey]_
in the option.

* When a packet contains both FROM_INCLUDED and SIGNATURE_INCLUDED (as in
  SYNCHRONIZE), the inference may be made directly.

* When a packet does not contain FROM_INCLUDED, the inference must be made from
  a previous SYNCHRONIZE packet.

* When a packet does not contain FROM_INCLUDED, and there was no previous
  SYNCHRONIZE packet (for example a stray CLOSE or RESET packet), the inference
  can be made from the length of the remaining options (since
  SIGNATURE_INCLUDED is the last option), but the packet will probably be
  discarded anyway, since there is no FROM available to validate the signature.
  If more option fields are defined in the future, they must be accounted for.


References
==========

.. [Destination]
    {{ ctags_url('Destination') }}

.. [Integer]
    {{ ctags_url('Integer') }}

.. [OfflineSig]
    {{ ctags_url('OfflineSignature') }}

.. [Signature]
    {{ ctags_url('Signature') }}

.. [SigningPrivateKey]
    {{ ctags_url('SigningPrivateKey') }}

.. [SigningPublicKey]
    {{ ctags_url('SigningPublicKey') }}

.. [STREAMING]
    {{ site_url('docs/api/streaming', True) }}

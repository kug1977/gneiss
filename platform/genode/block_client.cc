

#include <base/heap.h>
#include <block_session/connection.h>
#include <util/string.h>
#include <util/reconstructible.h>
#include <ada/exception.h>

#include <genode_packet.h>
namespace Cai {
#include <block_client.h>
}

extern "C"
{
    void __gnat_rcheck_CE_Access_Check()
    {
        throw Ada::Exception::Access_Check();
    }
}

Genode::Env *component_env __attribute__((weak)) = nullptr;
Genode::Constructible<Genode::Sliced_heap> _heap;
Genode::Constructible<Genode::Allocator_avl> _alloc;

class Block_session
{
    private:
        Block::Connection _block;
        Genode::Io_signal_handler<Cai::Block::Client> _event;
    public:
        Block_session(
                Genode::Env &env,
                Genode::Allocator_avl *alloc,
                Genode::size_t size,
                const char *device,
                Cai::Block::Client *client,
                void (Cai::Block::Client::*callback) ()) :
            _block(env, alloc, size, device),
            _event(env.ep(), *client, callback)
        {
            _block.tx_channel()->sigh_ack_avail(_event);
            _block.tx_channel()->sigh_ready_to_submit(_event);
        }

        ::Block::Connection *block()
        {
            return &_block;
        }
};

inline ::Block::Connection *blk(void *device)
{
    if (device){
        return reinterpret_cast<Block_session *>(device)->block();
    }else{
        Genode::error("Block connection device not initialized.");
        throw Ada::Exception::Access_Check();
    }
}

Cai::Block::Client::Client() :
    _block_count(0),
    _block_size(0),
    _device(nullptr),
    _callback(nullptr),
    _callback_state(nullptr)
{ }

void Cai::Block::Client::initialize(
        const char *device,
        void *callback,
        void *callback_state)
{
    const char default_device[] = "";
    Genode::size_t blk_size;
    if(component_env){
        _heap.construct(component_env->ram(), component_env->rm());
        _alloc.construct(&*_heap);
        _device = reinterpret_cast<void *>(new (*_heap) Block_session(
                *component_env,
                &*_alloc,
                128 * 1024,
                device ? device : default_device,
                this,
                &Client::callback));
        ::Block::Session::Operations ops;
        blk(_device)->info(&_block_count, &blk_size, &ops);
        _block_size = blk_size;
    }else{
        Genode::error("Failed to construct block session");
    }
    _callback = callback;
    _callback_state = callback_state;
}

void Cai::Block::Client::finalize()
{
    Genode::destroy (*_heap, reinterpret_cast<Block_session *>(_device));
    _device = nullptr;
    _callback = nullptr;
    _callback_state = nullptr;
}

void Cai::Block::Client::submit_read(Cai::Block::Request req)
{
    ::Block::Packet_descriptor packet(
            blk(_device)->dma_alloc_packet(block_size() * req.length),
            ::Block::Packet_descriptor::READ,
            req.start, req.length);
    blk(_device)->tx()->submit_packet(packet);
}

void Cai::Block::Client::submit_write(
        Cai::Block::Request req,
        Genode::uint8_t *data,
        Genode::uint64_t length)
{
    if(length > req.length * block_size()){
        throw Ada::Exception::Length_Check();
    }

    ::Block::Packet_descriptor packet(
            blk(_device)->dma_alloc_packet(length),
            ::Block::Packet_descriptor::WRITE,
            req.start, req.length);
    Genode::memcpy(blk(_device)->tx()->packet_content(packet), data, length);
    blk(_device)->tx()->submit_packet(packet);
}

void Cai::Block::Client::sync()
{ }

Cai::Block::Request Cai::Block::Client::next()
{
    Cai::Block::Request req = {Cai::Block::NONE, {}, 0, 0, Cai::Block::RAW};
    if(blk(_device)->tx()->ack_avail()){
        ::Block::Packet_descriptor packet = blk(_device)->tx()->get_acked_packet();
        req = create_cai_block_request(packet);
    }
    return req;
}

void Cai::Block::Client::read(
        Cai::Block::Request &req,
        Genode::uint8_t *data,
        Genode::uint64_t length)
{
    ::Block::Packet_descriptor packet = create_packet_descriptor(req);
    if(length < packet.size()){
        Genode::error (length, " < ", packet.size());
        req.status = ERROR;
    }else{
        Genode::memcpy(data, blk(_device)->tx()->packet_content(packet), packet.size());
        req.status = OK;
    }
}

void Cai::Block::Client::acknowledge(Cai::Block::Request req)
{
    ::Block::Packet_descriptor packet = create_packet_descriptor(req);
    if(packet.operation() == ::Block::Packet_descriptor::READ
            || packet.operation() == ::Block::Packet_descriptor::WRITE){
        blk(_device)->tx()->release_packet(packet);
    }
}

bool Cai::Block::Client::writable()
{
    ::Block::sector_t sector;
    Genode::size_t size;
    ::Block::Session::Operations ops;
    blk(_device)->info(&sector, &size, &ops);
    return ops.supported(::Block::Packet_descriptor::WRITE);
}

Genode::uint64_t Cai::Block::Client::block_count()
{
    return _block_count;
}

Genode::uint64_t Cai::Block::Client::block_size()
{
    return _block_size;
}

void Cai::Block::Client::callback()
{
    if(_callback){
        ((void (*)(void *))_callback)(_callback_state);
    }
}
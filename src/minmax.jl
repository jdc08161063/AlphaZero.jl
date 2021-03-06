#####
##### A simple minmax player to be used as a baseline
#####

"""
A simple implementation of the minmax tree search algorithm, to be used as
a baseline against AlphaZero. Heuristic board values are provided by the
[`GameInterface.heuristic_value`](@ref) function.
"""
module MinMax

import ..GI, ..GameInterface, ..AbstractPlayer, ..think

function current_player_value(white_reward, white_playing) :: Float64
  if iszero(white_reward)
    return 0.
  else
    v = Inf * sign(white_reward)
    return white_playing ? v : - v
  end
end

# Return the value of a state for the player playing
function value(game, depth)
  wr = GI.white_reward(game)
  wp = GI.white_playing(game)
  if isnothing(wr)
    if depth == 0
      return GI.heuristic_value(game)
    else
      return maximum(qvalue(game, a, depth)
        for a in GI.available_actions(game))
    end
  else
    return current_player_value(wr, wp)
  end
end

function qvalue(game, action, depth)
  @assert isnothing(GI.white_reward(game))
  next = copy(game)
  GI.play!(next, action)
  pswitch = GI.white_playing(game) != GI.white_playing(next)
  nextv = value(next, depth - 1)
  return pswitch ? - nextv : nextv
end

minmax(game, actions, depth) = argmax([qvalue(game, a, depth) for a in actions])

"""
    MinMax.Player{Game} <: AbstractPlayer{Game}

A stochastic minmax player, to be used as a baseline.

    MinMax.Player{Game}(;depth, τ=0.)

The minmax player explores the game tree exhaustively at depth `depth`
to build an estimate of the Q-value of each available action. Then, it
chooses an action as follows:

- If there are winning moves (with value `Inf`), one of them is picked
  uniformly at random.
- If all moves are losing (with value `-Inf`), one of them is picked
  uniformly at random.

Otherwise,

- If the temperature `τ` is zero, a move is picked uniformly among those
  with maximal Q-value (there is usually only one choice).
- If the temperature `τ` is nonzero, the probability of choosing
  action ``a`` is proportional to ``e^{\\frac{q_a}{Cτ}}`` where ``q_a`` is the
  Q value of action ``a`` and ``C`` is the maximum absolute value of all
  finite Q values, making the decision invariant to rescaling of
  [`GameInterface.heuristic_value`](@ref).
"""
struct Player{G} <: AbstractPlayer{G}
  depth :: Int
  τ :: Float64
  Player{G}(;depth, τ=0.) where G = new{G}(depth, τ)
end

function think(p::Player, game, turn=nothing)
  actions = GI.available_actions(game)
  n = length(actions)
  qs = [qvalue(game, a, p.depth) for a in actions]
  winning = findall(==(Inf), qs)
  if isempty(winning)
    notlosing = findall(>(-Inf), qs)
    best = argmax(qs)
    if isempty(notlosing)
      π = ones(n)
    elseif iszero(p.τ)
      π = zeros(n)
      all_best = findall(==(qs[best]), qs)
      π[all_best] .= 1.
    else
      qmax = qs[best]
      @assert qmax > -Inf
      C = maximum(abs(qs[a]) for a in notlosing) + eps()
      π = exp.((qs .- qmax) ./ C)
      π .^= (1 / p.τ)
    end
  else
    π = zeros(n)
    π[winning] .= 1.
  end
  π ./= sum(π)
  return actions, π
end

end
